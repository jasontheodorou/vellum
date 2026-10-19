#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# The journal: seeding, the index, the curator and the journal commands.

# Copy any missing starter files and folders into a journal. Never overwrites.
seed_journal() {
  local journal="$1" seed name today
  today="$(date '+%Y-%m-%d')"
  mkdir -p "$journal"
  for seed in "$TEMPLATES"/journal-seed/*; do
    name="$(basename "$seed")"
    # A kit journal keeps its lessons in training-manual.md.
    [ "$name" = "lessons.md" ] && [ -f "$journal/training-manual.md" ] && continue
    if [ -d "$seed" ]; then
      mkdir -p "$journal/$name"
      [ -n "$(ls -A "$journal/$name")" ] || touch "$journal/$name/.keep"
    elif [ ! -f "$journal/$name" ]; then
      sed "s/PLACEHOLDER/$today/g" "$seed" >"$journal/$name"
    fi
  done
}

# Print "date<US>status<US>summary" for an entry, from its frontmatter. US is
# the ASCII unit separator, which never appears in text and is never merged
# the way repeated tabs are.
# Falls back to the first heading, then the topic, when there is no summary.
entry_fields() {
  awk '
    NR == 1 && /^---$/ { fm = 1; next }
    fm && /^---$/ { fm = 0; next }
    fm {
      key = $0; sub(/:.*/, "", key)
      val = $0; sub(/^[^:]*:[[:space:]]*/, "", val)
      gsub(/^"|"$/, "", val)
      if (key == "date") date = val
      else if (key == "status") status = val
      else if (key == "summary") summary = val
      else if (key == "topic") topic = val
      next
    }
    !heading && /^# / { heading = substr($0, 3) }
    END {
      if (summary == "") summary = heading
      if (summary == "") summary = topic
      printf "%s\037%s\037%s\n", date, status, summary
    }' "$1"
}

# One line per entry: "- `path` (date, status): summary".
index_lines() {
  local journal="$1" dir="$2" f rel date status summary meta
  for f in "$journal/$dir"/*.md; do
    [ -f "$f" ] || continue
    rel="${f#"$journal"/}"
    IFS=$'\037' read -r date status summary <<EOF
$(entry_fields "$f")
EOF
    meta="$date"
    [ -n "$status" ] && meta="${meta:+$meta, }$status"
    echo "- \`$rel\`${meta:+ ($meta)}: $summary"
  done
}

# Rebuild INDEX.md from every entry's frontmatter. Cheap and predictable, so
# the curator never has to keep it in step by hand.
build_index() {
  local journal="$1" out tmp lines count f
  out="$journal/INDEX.md"
  tmp="$journal/.INDEX.tmp"
  {
    echo "---"
    echo "id: index"
    echo "type: index"
    echo "summary: Every journal entry with a one-line summary. Rebuilt automatically, so do not edit it."
    echo "---"
    echo
    echo "# Index"
    echo
    echo "## Start here"
    echo
    for f in overview lessons preferences glossary; do
      [ -f "$journal/$f.md" ] && echo "- \`$f.md\`: $(entry_fields "$journal/$f.md" | cut -d $'\037' -f3)"
    done
    for f in "$journal"/*.md; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in README.md|INDEX.md|overview.md|lessons.md|preferences.md|glossary.md) continue ;; esac
      echo "- \`$(basename "$f")\`: $(entry_fields "$f" | cut -d $'\037' -f3)"
    done

    lines="$(index_lines "$journal" decisions)"
    if [ -n "$lines" ]; then
      printf '\n## Decisions\n\n%s\n' "$lines"
    fi
    lines="$(index_lines "$journal" experiments)"
    if [ -n "$lines" ]; then
      printf '\n## Experiments\n\n%s\n' "$lines"
    fi
    lines="$(index_lines "$journal" weekly | sort -r)"
    if [ -n "$lines" ]; then
      printf '\n## Weekly round-ups\n\n%s\n' "$lines"
    fi
    lines="$(index_lines "$journal" logbook | sort -r)"
    if [ -n "$lines" ]; then
      count=$(printf '%s\n' "$lines" | wc -l | tr -d ' ')
      printf '\n## Logbook, newest first\n\n%s\n' "$(printf '%s\n' "$lines" | head -30)"
      [ "$count" -gt 30 ] && printf -- '- ...and %s older days in `logbook/`\n' "$((count - 30))"
    fi
    lines=""
    for f in "$journal"/artefacts/*; do
      [ -e "$f" ] && lines="$lines- \`artefacts/$(basename "$f")\`
"
    done
    [ -n "$lines" ] && printf '\n## Artefacts\n\n%s' "$lines"
  } >"$tmp"
  mv "$tmp" "$out"
}

# Shrink a Claude Code transcript to the conversation and one line per action.
# Prints nothing and fails when neither jq nor python3 is available.
condense_transcript() {
  local transcript="$1" out="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -R -r -f "$TEMPLATES/condense.jq" "$transcript" >"$out" 2>/dev/null && [ -s "$out" ] && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$transcript" >"$out" 2>/dev/null <<'PY' && [ -s "$out" ] && return 0
import json, sys

def clip(text, n):
    return text if len(text) <= n else text[:n] + " [...]"

def text_of(value):
    if isinstance(value, str):
        return value
    if value is None:
        return ""
    return json.dumps(value, separators=(",", ":"))

# Skip anything that is not the expected shape, the same as condense.jq.
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        rec = json.loads(line)
    except ValueError:
        continue
    if not isinstance(rec, dict):
        continue
    who = rec.get("type")
    if who not in ("user", "assistant") or rec.get("isMeta") not in (None, False):
        continue
    message = rec.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    if isinstance(content, str):
        content = [content]
    elif not isinstance(content, list):
        content = []
    for block in content:
        if isinstance(block, str):
            block = {"type": "text", "text": block}
        elif not isinstance(block, dict):
            continue
        kind = block.get("type")
        text = block.get("text")
        if kind == "text" and isinstance(text, str) and text.strip():
            label = "PERSON: " if who == "user" else "CLAUDE: "
            print(label + clip(text, 4000))
        elif kind == "tool_use":
            inp = block.get("input")
            detail = ""
            if isinstance(inp, dict):
                for key in ("file_path", "command", "pattern", "description", "url"):
                    if inp.get(key) not in (None, False):
                        detail = text_of(inp[key])
                        break
            print("ACTION: " + text_of(block.get("name")) + " " + clip(detail.replace("\n", " "), 200))
        elif kind == "tool_result" and block.get("is_error") not in (None, False):
            body = block.get("content")
            if isinstance(body, list):
                body = " ".join(text_of(b.get("text") or "") if isinstance(b, dict) else "" for b in body)
            print("FAILED: " + clip(text_of(body).replace("\n", " "), 300))
PY
  fi
  rm -f "$out"
  return 1
}

# Write the curator's instructions to a file. $1 is the session note.
# Every value goes in by environment and is swapped in as plain text, so
# characters such as & and \ in a project name come through unchanged.
write_curator_prompt() {
  local note="$1" out="$2"
  VELLUM_NOTE="$note" VELLUM_PROJECT="$(basename "$ROOT")" VELLUM_J="$JOURNAL_NAME" \
  VELLUM_LESSONS="$LESSONS" VELLUM_TODAY="$(date '+%Y-%m-%d')" awk '
    function swap(s, from, to,   out, i) {
      out = ""
      while ((i = index(s, from)) > 0) {
        out = out substr(s, 1, i - 1) to
        s = substr(s, i + length(from))
      }
      return out s
    }
    $0 == "{{SESSION_NOTE}}" { print ENVIRON["VELLUM_NOTE"]; next }
    {
      line = swap($0, "{{PROJECT}}", ENVIRON["VELLUM_PROJECT"])
      line = swap(line, "{{J}}", ENVIRON["VELLUM_J"])
      line = swap(line, "{{LESSONS}}", ENVIRON["VELLUM_LESSONS"])
      line = swap(line, "{{TODAY}}", ENVIRON["VELLUM_TODAY"])
      print line
    }' "$TEMPLATES/curator.md" >"$out"
}

# Run the curator in the project root. It may read the project and edit only
# inside the journal; it has no shell and no web access. $1 is the prompt file,
# $2 is an extra Read rule (or empty).
#
# Call snapshot_journal first. When the curator stops, this records which files
# it changed, so `vellum undo` can put back only those (see snapshot_finish).
run_curator() {
  local prompt_file="$1" extra_read="${2:-}" allowed result=0
  allowed="Edit(./$JOURNAL_NAME/**)"
  [ -n "$extra_read" ] && allowed="$allowed,$extra_read"
  set_model_args
  (cd "$ROOT" && VELLUM_SUBAGENT=1 CLAUDE_JOURNAL_HOOK=1 claude -p \
    --tools "Read,Glob,Grep,Edit,Write" \
    --permission-mode dontAsk \
    --allowedTools "$allowed" \
    --no-session-persistence \
    ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} <"$prompt_file") || result=$?
  snapshot_finish
  return $result
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_init() {
  set_project "$(project_root)"

  if [ "${1:-}" = "--decline" ]; then
    mkdir -p "$VELLUM_HOME"
    touch "$DECLINED"
    grep -qxF "$ROOT" "$DECLINED" || echo "$ROOT" >>"$DECLINED"
    echo "Vellum will not ask about $ROOT again."
    return 0
  fi

  if [ "$ROOT" = "$HOME_P" ]; then
    die "your home folder cannot have a journal. Open Claude in a project folder instead."
  fi
  if [ "$ROOT" = "$(projects_dir)" ]; then
    die "the projects folder itself cannot have a journal. Open Claude in one of the projects inside it instead."
  fi
  if has_legacy_journal "$ROOT"; then
    die "this project uses the old journal/ folder. Run 'vellum migrate' instead."
  fi
  [ -d "$TEMPLATES/journal-seed" ] || die "templates not found at $TEMPLATES"

  seed_journal "$JOURNAL"
  build_index "$JOURNAL"
  add_git_exclude "$ROOT"

  # Clear any earlier "no" for this project.
  if [ -f "$DECLINED" ]; then
    grep -vxF "$ROOT" "$DECLINED" >"$DECLINED.tmp" || true
    mv "$DECLINED.tmp" "$DECLINED"
  fi
  rm -f "$ROOT/.vellum-declined"

  echo "Journaling is on for $ROOT."
  if [ "$JOURNAL_NAME" = ".vellum" ]; then
    echo "The journal is in $JOURNAL_NAME/ and is kept out of git."
  else
    echo "The journal is in $JOURNAL_NAME/."
  fi
  if [ "$(config_get background on)" = "on" ]; then
    echo "After each session the curator, a background run of Claude, fills in anything missed."
    echo "It runs Claude, so it uses some of your plan's allowance. 'vellum config background off' stops it."
  fi
}

cmd_pause() {
  require_journal
  : >"$JOURNAL/.paused"
  echo "Journaling paused. Say 'resume journaling' to turn it back on."
}

cmd_resume() {
  require_journal
  rm -f "$JOURNAL/.paused"
  echo "Journaling resumed."
  # While paused, Claude was told only that journaling was off, so give it the
  # journal instructions and the journal now. print_project_context lives in
  # hooks.sh; without it, the next session start brings them instead.
  if type print_project_context >/dev/null 2>&1; then
    echo
    print_project_context "$ROOT"
  fi
}

count_md() {
  local n=0 f
  for f in "$1"/*.md; do [ -f "$f" ] && n=$((n + 1)); done
  echo "$n"
}

cmd_status() {
  set_project "$(project_root)"

  if [ ! -d "$JOURNAL" ]; then
    if has_legacy_journal "$ROOT"; then
      echo "This project has a journal from the old version. Run 'vellum migrate' to move it."
    elif is_declined "$ROOT"; then
      echo "Journaling is off for this project (you said no when asked)."
    else
      echo "Journaling is not on for this project."
    fi
    return 0
  fi

  if [ -f "$JOURNAL/.paused" ]; then
    echo "Journaling is paused."
  else
    echo "Journaling is on."
  fi
  echo "  logbook entries: $(count_md "$JOURNAL/logbook")"
  echo "  decisions:       $(count_md "$JOURNAL/decisions")"
  echo "  experiments:     $(count_md "$JOURNAL/experiments")"
  local latest
  latest=$(ls -1t "$JOURNAL"/logbook/*.md 2>/dev/null | head -1)
  [ -n "$latest" ] && echo "  last entry:      $(basename "$latest" .md)"
  echo "  curator:         $(config_get background on) (tidies the journal after each session)"
}

cmd_off() {
  local yes=0 tracked=0 force=0 arg
  for arg in "$@"; do
    case "$arg" in
      --yes) yes=1 ;;
      --delete-tracked) force=1 ;;
    esac
  done
  require_journal

  # A journal committed to git (the project kit's design-journal/) is shared
  # work: deleting it shows up as deleted files in the next commit.
  if command -v git >/dev/null 2>&1 && [ -n "$(git -C "$ROOT" ls-files -- "$JOURNAL_NAME" 2>/dev/null | head -1)" ]; then
    tracked=1
  fi
  if [ $tracked -eq 1 ] && [ $yes -eq 1 ] && [ $force -eq 0 ]; then
    die "the journal in $JOURNAL_NAME/ is tracked by git, so deleting it would delete committed files. Nothing changed. To delete it anyway, run 'vellum off --yes --delete-tracked'."
  fi

  if [ $yes -eq 0 ]; then
    [ $tracked -eq 1 ] && echo "The journal in $JOURNAL_NAME/ is tracked by git. Deleting it deletes committed files, which your next commit would record."
    printf "This deletes the journal for %s. Continue? (y/N) " "$ROOT"
    local reply
    read -r reply
    case "$reply" in
      y|Y|yes|YES) ;;
      *) echo "Nothing changed."; return 1 ;;
    esac
  fi

  rm -rf "$JOURNAL"
  remove_git_exclude "$ROOT"
  echo "Journaling is off for $ROOT and its journal has been deleted."
}

cmd_archive() {
  require_journal
  if [ $(( $(count_md "$JOURNAL/logbook") + $(count_md "$JOURNAL/decisions") + $(count_md "$JOURNAL/experiments") )) -eq 0 ]; then
    die "nothing to archive yet: the journal is empty"
  fi

  local proj_name proj_safe today desktop out lib_out tmp summary
  proj_name="$(basename "$ROOT")"
  proj_safe="$(__sanitize "$proj_name")"
  today="$(date '+%Y-%m-%d')"
  desktop="$(__desktop_path 2>/dev/null)"
  mkdir -p "$LIBRARY" "$desktop"
  out="$desktop/${proj_safe}_archive.md"
  lib_out="$LIBRARY/${proj_safe}_archive.md"
  tmp="$(mktemp)"

  # The summary comes from Claude, which may only read files in the project.
  summary=""
  set_model_args
  if command -v claude >/dev/null 2>&1; then
    summary=$(cd "$ROOT" && VELLUM_SUBAGENT=1 CLAUDE_JOURNAL_HOOK=1 claude -p \
      --tools "Read,Glob,Grep" \
      --permission-mode dontAsk \
      --no-session-persistence \
      ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} <<EOF 2>/dev/null || true
Read the project journal in ./$JOURNAL_NAME/ and write a summary of the project "$proj_name" of about 300 words, in plain prose with no headings or bullets. Cover what the project was and who it was for, the key decisions and why they were made, the most important lessons, and where the project ended up. Reply with the summary only.
EOF
)
  fi
  [ -n "$summary" ] || summary="(The automatic summary was not available. The rest of this archive has the detail.)"

  local sessions f
  sessions=$(count_md "$JOURNAL/logbook")
  {
    echo "---"
    echo "project: $proj_name"
    echo "archived: $today"
    echo "sessions: $sessions"
    echo "---"
    echo
    echo "# $proj_name"
    echo
    echo "## Summary"
    echo
    echo "$summary"
    echo
    if [ -f "$JOURNAL/overview.md" ] && ! grep -q '^Not written yet' "$JOURNAL/overview.md"; then
      echo "## Where it stands"
      echo
      strip_frontmatter "$JOURNAL/overview.md" | grep -v '^# ' | demote_headings
      echo
    fi

    echo "## Lessons learned"
    echo
    [ -f "$JOURNAL/$LESSONS" ] && strip_frontmatter "$JOURNAL/$LESSONS" | grep -v '^# ' | demote_headings
    echo

    if grep -q '^## ' "$JOURNAL/preferences.md" 2>/dev/null; then
      echo "## Preferences"
      echo
      strip_frontmatter "$JOURNAL/preferences.md" | grep -v '^# ' | demote_headings
      echo
    fi

    if [ "$(count_md "$JOURNAL/decisions")" -gt 0 ]; then
      echo "## Decisions"
      echo
      for f in "$JOURNAL"/decisions/*.md; do
        strip_frontmatter "$f" | demote_first_heading
        echo
      done
    fi

    if [ "$(count_md "$JOURNAL/experiments")" -gt 0 ]; then
      echo "## Experiments"
      echo
      for f in "$JOURNAL"/experiments/*.md; do
        strip_frontmatter "$f" | demote_first_heading
        echo
      done
    fi

    if [ -f "$JOURNAL/glossary.md" ]; then
      echo "## Glossary"
      echo
      strip_frontmatter "$JOURNAL/glossary.md" | grep -v '^# '
      echo
    fi

    if [ "$sessions" -gt 0 ]; then
      echo "## Recent activity"
      echo
      ls -1t "$JOURNAL"/logbook/*.md 2>/dev/null | head -10 | while IFS= read -r f; do
        strip_frontmatter "$f" | demote_first_heading
        echo
      done
    fi
  } >"$tmp"

  mv "$tmp" "$out"
  cp "$out" "$lib_out"
  echo "Saved to your desktop as ${proj_safe}_archive.md"
  echo "  desktop: $out"
  echo "  library: $lib_out"
}

# ---------------------------------------------------------------------------
# Snapshots, undo and the curator lock
#
# The order for any curator run is:
#   take the lock, snapshot_journal, run_curator, build_index, drop the lock.
# run_curator calls snapshot_finish itself. The background run in hooks.sh
# takes it in curate_root (take_project_lock); the commands here use take_curator_lock.
#
# .state/snapshots/STAMP.tgz      the journal before a run
# .state/undo/STAMP.before        a checksum of every file before the run
# .state/undo/STAMP.changes       the files the run changed, with their
#                                 checksums afterwards ("-" if it deleted one)
# .state/undo/pending             the run that has not finished yet
# .state/undo/undone              the last run was undone; set until the next
#                                 run changes something
# ---------------------------------------------------------------------------

# One curator per project at a time, the same lock the background run takes.
# A lock older than 30 minutes is stale. Released when the command exits.
take_curator_lock() {
  local lock="$JOURNAL/.state/lock"
  mkdir -p "$JOURNAL/.state"
  if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin -30 2>/dev/null)" ]; then
    die "the curator is working on this journal right now. Try again in a few minutes."
  fi
  rm -rf "${lock:?}"
  mkdir "$lock" 2>/dev/null || die "the curator is working on this journal right now. Try again in a few minutes."
  CURATOR_LOCK="$lock"
  trap 'release_curator_lock' EXIT
  trap 'exit 1' INT TERM
}

release_curator_lock() {
  if [ -n "${CURATOR_LOCK:-}" ]; then
    rmdir "$CURATOR_LOCK" 2>/dev/null || true
  fi
  CURATOR_LOCK=""
}

# Every file a curator run could change, one "checksum<TAB>./path" line each,
# sorted. INDEX.md is left out because it is rebuilt from the rest, and so are
# artefacts, the pause marker and Vellum's own state.
journal_manifest() {
  (cd "$JOURNAL" 2>/dev/null && find . -type f \
    ! -path './.state/*' ! -path './artefacts/*' ! -path './.paused' \
    ! -path './INDEX.md' ! -path './.INDEX.tmp' -exec cksum {} + 2>/dev/null) |
    awk '{ sum = $1 "-" $2; sub(/^[^ ]+ [^ ]+ /, ""); print sum "\t" $0 }' | LC_ALL=C sort -t "$(printf '\t')" -k2
}

# Turn a snapshot's name, such as 2026-10-16-143005, into "2026-10-16 at 14:30".
snapshot_when() {
  printf '%s' "$1" | awk -F- '{printf "%s-%s-%s at %s:%s", $1, $2, $3, substr($4, 1, 2), substr($4, 3, 2)}'
}

# Throw away a snapshot and its records.
drop_snapshot() {
  local stamp="${1:?}"
  rm -f "$JOURNAL/.state/snapshots/$stamp.tgz" "$JOURNAL/.state/undo/$stamp.before" "$JOURNAL/.state/undo/$stamp.changes"
}

# Keep the ten most recent snapshots of curator runs, and the three most
# recent copies saved by undo.
prune_snapshots() {
  local dir="$JOURNAL/.state/snapshots" old
  ls -1 "$dir" 2>/dev/null | grep -- '\.tgz$' | grep -v -- '-before-undo\.tgz$' | sort -r | tail -n +11 |
    while IFS= read -r old; do drop_snapshot "${old%.tgz}"; done
  ls -1 "$dir" 2>/dev/null | grep -- '-before-undo\.tgz$' | sort -r | tail -n +4 |
    while IFS= read -r old; do rm -f "${dir:?}/${old:?}"; done
}

# Save the journal as it is now, before the curator changes it. Artefacts are
# left out: the curator does not edit them, and they can be large.
snapshot_journal() {
  local dir="$JOURNAL/.state/snapshots" rec="$JOURNAL/.state/undo" stamp old
  mkdir -p "$dir" "$rec"
  # A run that never finished (the computer slept, say) cannot be undone safely.
  old="$(cat "$rec/pending" 2>/dev/null)"
  [ -n "$old" ] && drop_snapshot "$old"
  rm -f "$rec/pending"
  stamp="$(date '+%Y-%m-%d-%H%M%S')"
  if ! (cd "$JOURNAL" && tar -czf "$dir/$stamp.tgz" --exclude './.state' --exclude './artefacts' --exclude './.paused' . 2>/dev/null); then
    rm -f "$dir/$stamp.tgz"
    return 0
  fi
  journal_manifest >"$rec/$stamp.before"
  echo "$stamp" >"$rec/pending"
  prune_snapshots
}

# After a curator run: record which files it changed. A run that changed
# nothing leaves no snapshot behind, so undo never claims to undo nothing.
# Sets CURATOR_CHANGED to the number of files changed.
snapshot_finish() {
  local rec="$JOURNAL/.state/undo" stamp
  CURATOR_CHANGED=0
  stamp="$(cat "$rec/pending" 2>/dev/null)"
  rm -f "$rec/pending"
  [ -n "$stamp" ] && [ -f "$rec/$stamp.before" ] || return 0
  journal_manifest | awk -F'\t' '
    NR == FNR { before[$2] = $1; next }
    { now[$2] = 1; if (!($2 in before) || before[$2] != $1) print $1 "\t" $2 }
    END { for (p in before) if (!(p in now)) print "-\t" p }' "$rec/$stamp.before" - >"$rec/$stamp.changes"
  CURATOR_CHANGED=$(grep -c . "$rec/$stamp.changes")
  if [ "$CURATOR_CHANGED" -eq 0 ]; then
    drop_snapshot "$stamp"
  else
    rm -f "$rec/undone"
  fi
  return 0
}

# Curator runs that changed something and can be undone, newest first.
undoable_snapshots() {
  local rec="$JOURNAL/.state/undo" f
  ls -1 "$rec" 2>/dev/null | grep -- '\.changes$' | sort -r | while IFS= read -r f; do
    [ -f "$JOURNAL/.state/snapshots/${f%.changes}.tgz" ] && echo "${f%.changes}"
  done
  return 0
}

# Put back the files the curator's most recent run changed, as they were
# before it. Notes written since are kept. If any of those same files has
# changed since the run, nothing is touched and the files are named.
# The journal as it was is saved first, so an undo can itself be undone by hand.
cmd_undo() {
  local earlier=0
  [ "${1:-}" = "--earlier" ] && earlier=1
  require_journal
  take_curator_lock
  local dir="$JOURNAL/.state/snapshots" rec="$JOURNAL/.state/undo" stamp when changed path older n
  local restore=() remove=()
  stamp="$(undoable_snapshots | head -1)"
  [ -n "$stamp" ] || die "there is nothing to undo: the curator has not changed this journal since it was last undone"
  when="$(snapshot_when "$stamp")"
  if [ -f "$rec/undone" ] && [ $earlier -eq 0 ]; then
    die "the curator's last update is already undone. To also undo its earlier update from $when, run 'vellum undo --earlier'."
  fi

  # Stop if anyone has changed the same files since the curator did.
  changed="$(journal_manifest | awk -F'\t' '
    NR == FNR { now[$2] = $1; next }
    { cur = ($2 in now) ? now[$2] : "-"; if (cur != $1) print $2 }' - "$rec/$stamp.changes")"
  if [ -n "$changed" ]; then
    {
      echo "vellum: nothing was undone. These files have changed since the curator's update on $when, and undoing it would lose those changes:"
      printf '%s\n' "$changed" | sed "s|^\./|  $JOURNAL_NAME/|"
      echo "Edit them by hand instead. Earlier versions are in $JOURNAL_NAME/.state/snapshots/."
    } >&2
    exit 1
  fi

  # Files that were there before the run go back; files it added go.
  while IFS="$(printf '\t')" read -r _ path; do
    [ -n "$path" ] || continue
    if awk -F'\t' -v p="$path" '$2 == p {found = 1} END {exit !found}' "$rec/$stamp.before"; then
      restore+=("$path")
    else
      remove+=("$path")
    fi
  done <"$rec/$stamp.changes"

  (cd "$JOURNAL" && tar -czf "$dir/$(date '+%Y-%m-%d-%H%M%S')-before-undo.tgz" --exclude './.state' --exclude './artefacts' --exclude './.paused' .) ||
    die "could not save a copy of the journal first, so nothing was undone"
  if [ ${#restore[@]} -gt 0 ]; then
    (cd "$JOURNAL" && tar -xzf "$dir/$stamp.tgz" "${restore[@]}") || die "could not unpack the snapshot from $when"
  fi
  for path in ${remove[@]+"${remove[@]}"}; do
    rm -f "$JOURNAL/${path:?}"
  done
  n=$(( ${#restore[@]} + ${#remove[@]} ))
  drop_snapshot "$stamp"
  : >"$rec/undone"
  prune_snapshots
  build_index "$JOURNAL"
  # The "Journal updated" message for this project no longer applies.
  rm -f "$VELLUM_HOME/notices/$(__sanitize "$ROOT")"
  # Without this, the curator would run when this session ends and could redo
  # the very update that was just undone.
  : >"$JOURNAL/.state/skip-next"
  release_curator_lock
  echo "The journal is back as it was on $when, before the curator's last update. $n file$( [ "$n" -ne 1 ] && echo s) put back; anything written since was kept."
  echo "The version you just replaced is saved in $JOURNAL_NAME/.state/snapshots/ if you need it."
  older="$(undoable_snapshots | head -1)"
  [ -n "$older" ] && echo "An earlier update from $(snapshot_when "$older") can also be undone with 'vellum undo --earlier'."
  return 0
}

cmd_curate() {
  require_journal
  command -v claude >/dev/null 2>&1 || die "Claude Code is not on PATH, so the curator cannot run"
  take_curator_lock
  local prompt_file
  snapshot_journal
  prompt_file="$(mktemp)"
  write_curator_prompt "There is no new session to record, so skip step 2. Tidy the journal that is already there: turn decisions, experiments, lessons and preferences buried in the logbook into proper entries (step 3), then carry out step 4." "$prompt_file"
  echo "Curating the journal. This can take a minute or two."
  if ! run_curator "$prompt_file" ""; then
    rm -f "$prompt_file"
    build_index "$JOURNAL"
    die "the curator did not finish"
  fi
  rm -f "$prompt_file"
  build_index "$JOURNAL"
  release_curator_lock
  if [ "${CURATOR_CHANGED:-0}" -gt 0 ]; then
    echo "The curator updated $CURATOR_CHANGED file$( [ "$CURATOR_CHANGED" -ne 1 ] && echo s). Say \"undo the journal update\" to reverse it."
  else
    echo "The curator made no changes."
  fi
}

cmd_index() {
  require_journal
  build_index "$JOURNAL"
  echo "Rebuilt $JOURNAL_NAME/INDEX.md."
}

# Load another project's background at the start of every session here: a live
# project on the list, or an archived one in the library.
cmd_link() {
  local name="${1:-}" safe archive imports entry
  [ -n "$name" ] || { echo "Usage: vellum link <project-name>" >&2; return 2; }
  safe="$(__sanitize "$name")"
  archive="$LIBRARY/${safe}_archive.md"
  if [ -n "$(reg_line "$name")" ]; then
    entry="project:$name"
  elif [ -f "$archive" ]; then
    entry="$safe"
  else
    entry="project:$(resolve_project "$name" 2>/dev/null)" || entry=""
    [ "$entry" != "project:" ] && [ -n "$entry" ] || die "'$name' is not on the project list or in the library at $LIBRARY."
  fi
  require_journal
  if [ "$entry" = "project:$(reg_name_for_path "$ROOT")" ]; then
    die "this is the project '${entry#project:}' itself, so there is nothing to link."
  fi
  imports="$JOURNAL/.imports"
  if [ ! -f "$imports" ] || ! grep -qxF "$entry" "$imports"; then
    echo "$entry" >>"$imports"
  fi
  echo "Linked ${entry#project:}. Its overview and lessons will load at the start of every session here."
}

# Stop loading a linked project. Finds it the same way link does: the exact
# name, then the project list (which accepts part of a name), then part of a
# name among the links themselves.
cmd_unlink() {
  local name="${1:-}" safe imports entry="" resolved matches
  [ -n "$name" ] || { echo "Usage: vellum unlink <project-name>" >&2; return 2; }
  safe="$(__sanitize "$name")"
  require_journal
  imports="$JOURNAL/.imports"
  [ -s "$imports" ] || die "nothing is linked to this project."
  if grep -qxF "project:$name" "$imports"; then
    entry="project:$name"
  elif grep -qxF "$safe" "$imports"; then
    entry="$safe"
  elif resolved="$(resolve_project "$name" 2>/dev/null)" && grep -qxF "project:$resolved" "$imports"; then
    entry="project:$resolved"
  else
    matches="$(awk -v q="$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')" '
      { n = $0; sub(/^project:/, "", n); if (index(tolower(n), q)) print }' "$imports")"
    [ "$(printf '%s' "$matches" | grep -c .)" -eq 1 ] && entry="$matches"
  fi
  if [ -z "$entry" ]; then
    {
      echo "vellum: nothing is linked under the name '$name'. Linked here:"
      sed 's/^project://; s/^/  /' "$imports"
    } >&2
    exit 1
  fi
  grep -vxF "$entry" "$imports" >"$imports.tmp" || true
  mv "$imports.tmp" "$imports"
  [ -s "$imports" ] || rm -f "$imports"
  echo "Unlinked ${entry#project:}."
}

cmd_library() {
  local f found=0
  for f in "$LIBRARY"/*_archive.md; do
    [ -f "$f" ] || continue
    [ $found -eq 0 ] && echo "Archived projects:"
    found=1
    echo "  $(basename "$f" _archive.md) (archived $(awk -F': ' '/^archived:/ {print $2; exit}' "$f"))"
  done
  [ $found -eq 1 ] || echo "There are no archived projects yet."
}

# Move a project from the old journal/ layout to .vellum/.
cmd_migrate() {
  set_project "$(project_root)"
  has_legacy_journal "$ROOT" || die "there is no old journal/ folder to move in $ROOT"
  [ -e "$JOURNAL" ] && die "$JOURNAL already exists, so the old journal was left where it is"

  mv "$ROOT/journal" "$JOURNAL"
  [ -f "$JOURNAL/.imports.txt" ] && mv "$JOURNAL/.imports.txt" "$JOURNAL/.imports"
  rm -rf "$JOURNAL/.scribe.state.d" "$JOURNAL/.scribe.log"

  # Take the managed block out of CLAUDE.md and delete the file if nothing is left.
  awk '/<!-- scribe-block-begin -->/ {skip=1; next} /<!-- scribe-block-end -->/ {skip=0; next} !skip {print}' \
    "$ROOT/CLAUDE.md" >"$ROOT/CLAUDE.md.tmp"
  awk 'NR==FNR {if (NF) last=NR; next} FNR<=last' "$ROOT/CLAUDE.md.tmp" "$ROOT/CLAUDE.md.tmp" >"$ROOT/CLAUDE.md"
  rm -f "$ROOT/CLAUDE.md.tmp"
  [ -s "$ROOT/CLAUDE.md" ] || rm -f "$ROOT/CLAUDE.md"

  if [ -f "$ROOT/.gitignore" ]; then
    grep -vx "journal/" "$ROOT/.gitignore" >"$ROOT/.gitignore.tmp" || true
    mv "$ROOT/.gitignore.tmp" "$ROOT/.gitignore"
    [ -s "$ROOT/.gitignore" ] || rm -f "$ROOT/.gitignore"
  fi
  add_git_exclude "$ROOT"

  echo "Moved the journal from journal/ to $JOURNAL_NAME/ and removed the old Scribe block from CLAUDE.md."
  echo "Check 'git status': CLAUDE.md and .gitignore may now show as changed."
}

# Undo what the old curl installer did to Claude Code and the shell.
# Archived projects in ~/.vellum/library are kept.
cmd_remove_old_install() {
  local claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}" f rc tmp failed=0
  local settings="$claude_dir/settings.json"
  if [ -f "$settings" ] && grep -q '\.scribe/hooks/' "$settings"; then
    local updated=""
    if command -v jq >/dev/null 2>&1; then
      updated=$(jq '
        if .hooks then
          .hooks |= with_entries(.value |= map(select(
            (.scribe != true) and
            ((.hooks // []) | map(.command // "") | any(test("\\.scribe/hooks/")) | not)
          )))
          | .hooks |= with_entries(select(.value | length > 0))
        else . end' "$settings") || updated=""
    elif command -v python3 >/dev/null 2>&1; then
      updated=$(python3 - "$settings" <<'PY'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
hooks = data.get("hooks", {})
for event in list(hooks):
    kept = [g for g in hooks[event]
            if not g.get("scribe")
            and not any(".scribe/hooks/" in h.get("command", "") for h in g.get("hooks", []))]
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
print(json.dumps(data, indent=2))
PY
) || updated=""
    fi
    if [ -z "$updated" ]; then
      die "could not edit $settings (needs jq or python3). Remove the two entries that mention .scribe/hooks/ by hand."
    fi
    cp "$settings" "$settings.vellum-backup"
    printf '%s\n' "$updated" >"$settings"
    echo "Removed the old hooks from $settings (backup saved as settings.json.vellum-backup)."
  fi

  for f in journal-pause.md journal-resume.md journal-status.md; do
    [ -f "$claude_dir/commands/$f" ] && grep -q 'scribe' "$claude_dir/commands/$f" && rm -f "$claude_dir/commands/$f"
  done

  # Take the old PATH line out of each shell file. The new text is written
  # through the file, so a ~/.zshrc that is a link to a dotfiles folder stays
  # a link. awk is used rather than grep -v, which fails when it prints
  # nothing (a file holding only the old line).
  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] || continue
    grep -q '\.scribe/bin' "$rc" || continue
    tmp="$(mktemp)" || { echo "vellum: could not make a temporary file, so $rc was left alone." >&2; failed=1; continue; }
    if awk '!/\.scribe\/bin/ && $0 != "# scribe"' "$rc" >"${tmp:?}" && cat "$tmp" >"$rc" 2>/dev/null && ! grep -q '\.scribe/bin' "$rc"; then
      echo "Removed the old PATH line from $rc."
    else
      echo "vellum: could not remove the old PATH line from $rc. Delete the line that mentions .scribe/bin by hand." >&2
      failed=1
    fi
    rm -f "${tmp:?}"
  done

  rm -rf "${OLD_HOME:?}/bin" "${OLD_HOME:?}/hooks" "${OLD_HOME:?}/templates" \
         "${OLD_HOME:?}/uninstall.sh" "${OLD_HOME:?}/VERSION"
  rmdir "$OLD_HOME" 2>/dev/null || true
  if [ $failed -eq 1 ]; then
    echo "The rest of the old install is gone. Archived projects in $LIBRARY were kept."
    return 1
  fi
  echo "The old install is gone. Archived projects in $LIBRARY were kept."
}

cmd_doctor() {
  local issues=0
  echo "Vellum $(plugin_version)"
  if [ "$(uname -s)" = "Darwin" ]; then
    echo "  ok   running on macOS $(sw_vers -productVersion 2>/dev/null)"
  else
    echo "  FAIL Vellum is for macOS only"
    issues=$((issues + 1))
  fi
  if command -v claude >/dev/null 2>&1; then
    echo "  ok   Claude Code is installed"
  else
    echo "  FAIL Claude Code is not on PATH, so archive summaries and the curator cannot run"
    issues=$((issues + 1))
  fi
  if command -v git >/dev/null 2>&1; then
    echo "  ok   git is installed"
  else
    echo "  note git is not installed, so journals cannot be excluded from git"
  fi
  if command -v jq >/dev/null 2>&1; then
    echo "  ok   jq is installed"
  else
    echo "  note jq is not installed (optional)"
  fi
  if [ -d "$TEMPLATES/journal-seed" ]; then
    echo "  ok   templates found"
  else
    echo "  FAIL templates missing from $TEMPLATES"
    issues=$((issues + 1))
  fi
  if has_legacy_install; then
    echo "  FAIL the old curl install is still wired in. Run 'vellum remove-old-install'"
    issues=$((issues + 1))
  else
    echo "  ok   no old install left over"
  fi
  echo "  ok   curator after each session: $(config_get background on), model: $(config_get model default)"

  # The look and the status line, which install.sh sets up. Notes only: the
  # journal and projects work without them.
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  if [ -f "$settings" ] && grep -qE '"theme"[[:space:]]*:[[:space:]]*"custom:vellum"' "$settings"; then
    echo "  ok   Claude Code uses Vellum's theme"
  elif [ ! -f "$THEME_PREVIOUS" ] && [ -f "$THEME_INSTALLED" ]; then
    # `vellum theme undo` put both looks back on purpose, so say nothing.
    :
  else
    echo "  note Claude Code's theme is not Vellum's, so its colours may clash with the Vellum profile. Run 'vellum theme'"
  fi
  if [ -f "$settings" ] && grep -qE '"command"[[:space:]]*:[[:space:]]*"[^"]*vellum statusline"' "$settings"; then
    echo "  ok   the status line is Vellum's"
  else
    echo "  note the status line is not Vellum's, so it does not show each project's shape and port"
  fi
  if [ ! -f "$HOME/Library/Fonts/PaperMono-Regular.otf" ]; then
    echo "  note Paper Mono is not installed. 'vellum theme' installs it"
  elif has_terminal_profile "$THEME_NAME" && [ "$(profile_font)" != "$PROFILE_FONT $PROFILE_FONT_SIZE" ]; then
    echo "  note the Vellum profile uses $(profile_font), not Paper Mono $PROFILE_FONT_SIZE. 'vellum theme' fixes it"
  else
    echo "  ok   Paper Mono is installed"
  fi
  echo
  if [ $issues -eq 0 ]; then
    echo "Everything looks healthy."
  else
    echo "$issues problem(s) found."
    return 1
  fi
}
