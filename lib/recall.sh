#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# Recall: search every past Claude Code conversation on this computer.
#
# Claude Code saves each conversation as JSON lines under ~/.claude/projects/.
# Each one is condensed once (about a hundredth of the size) into
# ~/.vellum/recall/, with a short header, and refreshed only when it changes.
# Curator runs (and older journal helpers) are skipped, and so are
# conversations from projects where journaling is paused or was declined.

transcripts_root() {
  echo "${VELLUM_TRANSCRIPTS:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}"
}

recall_dir() {
  echo "$VELLUM_HOME/recall"
}

# Print the header lines for a transcript: title, first and last date, and the
# projects it worked in (folders inside the projects folder).
transcript_meta() {
  local transcript="$1" pdir="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg p "$pdir/" '
      if .type == "ai-title" and .aiTitle then "T\t" + .aiTitle
      elif .timestamp then "D\t" + .timestamp + (if (.cwd // "") | startswith($p) then "\nP\t" + (.cwd | ltrimstr($p) | split("/")[0]) else "" end)
      else empty end' "$transcript" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$transcript" "$pdir/" <<'PY' 2>/dev/null
import json, sys
path, pdir = sys.argv[1], sys.argv[2]
for line in open(path, encoding="utf-8", errors="replace"):
    try:
        rec = json.loads(line)
    except ValueError:
        continue
    if rec.get("type") == "ai-title" and rec.get("aiTitle"):
        print("T\t" + rec["aiTitle"])
    elif rec.get("timestamp"):
        print("D\t" + rec["timestamp"])
        cwd = rec.get("cwd") or ""
        if cwd.startswith(pdir):
            print("P\t" + cwd[len(pdir):].split("/")[0])
PY
  fi | awk -F'\t' '
    $1 == "T" { title = $2 }
    $1 == "D" { if (first == "") first = $2; last = $2 }
    $1 == "P" && $2 != "" && !seen[$2]++ { projects = projects (projects ? ", " : "") $2 }
    END {
      print "# title: " title
      print "# first: " substr(first, 1, 10)
      print "# last: " substr(last, 1, 10)
      print "# projects: " projects
    }'
}

# A conversation that the curator had with Claude, not a person.
is_helper_text() {
  head -1 "$1" | grep -qE '^PERSON: (You are the (journal safety net|curator)|You keep the journal|Read the project journal in )'
}

# Condense one transcript into the recall folder, if it is new or has changed.
recall_cache_one() {
  local transcript="$1" id cache body
  id="$(basename "$transcript" .jsonl)"
  cache="$(recall_dir)/$id.txt"
  [ -f "$cache" ] && [ ! "$transcript" -nt "$cache" ] && return 0
  # Paused or declined: not copied, and no skip record either, so it is
  # picked up if journaling is turned back on.
  transcript_is_private "$transcript" && return 0
  mkdir -p "$(recall_dir)"
  body="$(recall_dir)/.$id.body"
  if ! condense_transcript "$transcript" "$body" || is_helper_text "$body"; then
    # Nothing a person said, or a helper's run: remember to skip it.
    printf '# skip: yes\n' >"$cache"
    rm -f "$body"
    return 0
  fi
  {
    transcript_meta "$transcript" "$(projects_dir)"
    echo "# id: $id"
    echo
    cat "$body"
  } >"$cache"
  rm -f "$body"
}

# A conversation that started in a project where journaling is paused, or
# where the person said no to Vellum. Recall does not copy these. The folder
# it started in, and each folder above it, is checked for the pause marker
# and the "no" markers, so no git calls are needed.
transcript_is_private() {
  local cwd dir
  cwd="$(grep -m1 -oE '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' "$1" 2>/dev/null | head -1 | sed -E 's/^"cwd"[[:space:]]*:[[:space:]]*"//; s/"$//')"
  [ -n "$cwd" ] || return 1
  dir="$cwd"
  while [ -n "$dir" ] && [ "$dir" != "/" ] && [ "$dir" != "$HOME_P" ] && [ "$dir" != "$HOME" ]; do
    [ -f "$dir/.vellum/.paused" ] && return 0
    [ -f "$dir/design-journal/.paused" ] && [ ! -d "$dir/.vellum" ] && return 0
    { [ -f "$dir/.vellum-declined" ] || [ -f "$dir/.scribe-declined" ]; } && return 0
    [ -f "$DECLINED" ] && grep -qxF "$dir" "$DECLINED" && return 0
    dir="${dir%/*}"
  done
  return 1
}

# Bring the recall folder up to date with every saved conversation. Stops
# after about a minute (VELLUM_RECALL_BUDGET seconds), so a first search over
# many conversations never runs past a tool's time limit; the next search
# carries on where this one stopped.
recall_update() {
  local root f todo="" count=0 done_n=0 left=0 budget start cache
  root="$(transcripts_root)"
  [ -d "$root" ] || return 0
  budget="${VELLUM_RECALL_BUDGET:-60}"
  for f in "$root"/*/*.jsonl; do
    [ -f "$f" ] || continue
    cache="$(recall_dir)/$(basename "$f" .jsonl).txt"
    if [ ! -f "$cache" ] || [ "$f" -nt "$cache" ]; then
      transcript_is_private "$f" && continue
      todo="$todo$f
"
      count=$((count + 1))
    fi
  done
  [ $count -gt 0 ] || return 0
  [ $count -gt 20 ] && echo "Reading $count past conversations for the first time. This can take a few minutes, once." >&2
  start=$SECONDS
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if [ $((SECONDS - start)) -ge "$budget" ]; then
      left=$((left + 1))
      continue
    fi
    recall_cache_one "$f"
    done_n=$((done_n + 1))
  done <<EOF
$todo
EOF
  if [ $left -gt 0 ]; then
    echo "Read $done_n past conversations; $left are still to read. Results below cover only those read so far. Run the same search again to carry on." >&2
  fi
  return 0
}

# The pattern for one search word, escaped. A word that starts with a letter
# or digit must start a word in the text, so "drain" finds "drains" but
# "beds" does not find "embeds". A word that starts with punctuation, such as
# ".env" or "$5", is matched anywhere, because \b never comes before
# punctuation that follows a space.
word_pattern() {
  case "$1" in
    [A-Za-z0-9]*) printf '\\b%s' "$(regex_escape "$1")" ;;
    *) regex_escape "$1" ;;
  esac
}

# Escape a word for use in an extended regular expression.
regex_escape() {
  printf '%s' "$1" | sed 's/[][\.*^$(){}?+|/]/\\&/g'
}

# Turn "2026-10-16" into "16 Oct 2026".
nice_date() {
  printf '%s' "$1" | awk -F- '{
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
    if (NF == 3) printf "%d %s %s", $3, m[$2 + 0], $1; else printf "%s", $0 }'
}

header_value() {
  sed -n "s/^# $2: //p" "$1" | head -1
}

# vellum recall WORDS [--project NAME] [--limit N] [--session ID]
# vellum recall --show ID [WORDS]
cmd_recall() {
  local words=() project="" limit=5 exclude="" show="" f id score w ok scored="" title last projects
  local match=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --project) project="${2:-}"; shift 2 || shift ;;
      --limit) limit="${2:-5}"; shift 2 || shift ;;
      --session) exclude="${2:-}"; shift 2 || shift ;;
      --show) show="${2:-}"; shift 2 || shift ;;
      *) words+=("$1"); shift ;;
    esac
  done
  # Accept "magic links" as one argument or two.
  local joined="${words[*]:-}"
  words=()
  set -f
  for w in $joined; do
    [ ${#w} -ge 2 ] && words+=("$w")
  done
  set +f
  # Match the start of words, so "drain" finds "drains" and "drainage" but
  # "beds" does not find "embeds".
  for w in ${words[@]+"${words[@]}"}; do match+=(-e "$(word_pattern "$w")"); done

  recall_update

  if [ -n "$show" ]; then
    recall_show "$show" ${words[@]+"${words[@]}"}
    return
  fi
  [ ${#words[@]} -gt 0 ] || die "say what to look for"

  for f in "$(recall_dir)"/*.txt; do
    [ -f "$f" ] || continue
    head -1 "$f" | grep -q '^# skip: yes' && continue
    id="$(basename "$f" .txt)"
    [ "$id" = "$exclude" ] && continue
    if [ -n "$project" ]; then
      header_value "$f" projects | grep -qiF "$project" || continue
    fi
    # Every word must appear somewhere in the conversation.
    ok=1
    for w in "${words[@]}"; do
      grep -qiE -- "$(word_pattern "$w")" "$f" || { ok=0; break; }
    done
    [ $ok -eq 1 ] || continue
    # Lines with any of the words, plus a bonus for the exact phrase.
    score=$(( $(grep -ciE "${match[@]}" "$f") + 5 * $(grep -ciF -- "${words[*]}" "$f") ))
    scored="$scored$score	$(header_value "$f" last)	$f
"
  done

  if [ -z "$scored" ]; then
    echo "No past conversation mentions all of: ${words[*]}."
    return 0
  fi

  printf '%s' "$scored" | sort -t "$TAB" -k1,1nr -k2,2r | head -n "$limit" | while IFS="$TAB" read -r score last f; do
    id="$(basename "$f" .txt)"
    title="$(header_value "$f" title)"
    projects="$(header_value "$f" projects)"
    echo "## $(nice_date "$last")${title:+ · \"$title\"}${projects:+ · $projects} · $id"
    # The best few lines: those with the most of the words in them.
    grep -iE "${match[@]}" "$f" | grep -v '^# ' | awk -v words="$(printf '%s ' "${words[@]}" | tr '[:upper:]' '[:lower:]')" '
      BEGIN { n = split(words, w, " "); phrase = words; sub(/ $/, "", phrase) }
      { l = tolower($0); s = 0; for (i = 1; i <= n; i++) if (index(l, w[i])) s++
        if (n > 1 && index(l, phrase)) s += n
        print s "\t" NR "\t" $0 }' |
      sort -t "$TAB" -k1,1nr -k2,2n | head -3 | cut -f3- | cut -c1-260 | sed 's/^/  /'
    echo
  done
  echo "To read more of one: vellum recall --show <id> \"words\""
}

# Print part of one past conversation: around the words if given, otherwise
# the start.
recall_show() {
  local id="$1" f line from w match=()
  shift
  for w in "$@"; do match+=(-e "$w"); done
  f="$(recall_dir)/$id.txt"
  [ -f "$f" ] || f="$(ls "$(recall_dir)"/"$id"*.txt 2>/dev/null | head -1)"
  [ -f "$f" ] || die "there is no past conversation with the id $id"
  echo "# $(header_value "$f" title) ($(nice_date "$(header_value "$f" first)") to $(nice_date "$(header_value "$f" last)"))"
  echo "# projects: $(header_value "$f" projects)"
  echo
  if [ $# -gt 0 ]; then
    line=$(grep -niF "${match[@]}" "$f" | grep -v '^[0-9]*:# ' | head -1 | cut -d: -f1)
    if [ -n "$line" ]; then
      from=$(( line > 20 ? line - 20 : 1 ))
      sed -n "${from},$((from + 80))p" "$f" | grep -v '^# ' | cut -c1-600
      echo
      echo "(Lines $from to $((from + 80)) of $(wc -l <"$f" | tr -d ' ').)"
      return 0
    fi
  fi
  grep -v '^# ' "$f" | head -120 | cut -c1-600
  echo
  echo "(The first 120 lines of $(wc -l <"$f" | tr -d ' ').)"
}
