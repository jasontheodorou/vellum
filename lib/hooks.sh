#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# The SessionStart and SessionEnd hooks, the curator that runs after a session
# ends, and the project context they share with `vellum open`, `vellum new`
# and `vellum resume`.

# Claude Code replaces hook output over 10,000 characters with a short preview,
# and Claude then loses the journal. So everything session start prints stays
# under this many characters, counted as they appear once encoded as JSON.
CONTEXT_BUDGET=9000

# How many characters some text takes once encoded as a JSON string: each byte,
# plus one for every newline, quote, backslash or tab, which become two.
# Counting bytes, not letters, errs on the safe side.
json_size() {
  LC_ALL=C awk '{ n += length($0) + 2 + gsub(/["\\\t]/, "&") } END { print n + 2 }'
}

# Print as many whole lines as fit in a budget of JSON characters.
fit_to_budget() {
  LC_ALL=C awk -v max="$1" '{ n += length($0) + 2 + gsub(/["\\\t]/, "&"); if (n > max) exit; print }'
}

# Make text safe to use as a sed replacement with | as the separator.
sed_escape() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

# ---------------------------------------------------------------------------
# The project context
# ---------------------------------------------------------------------------

# Print the journal instructions and the journal itself for a project: the
# same block session start shows. $1 is the project root (optional, otherwise
# the project set_project chose); $2 is a budget in JSON characters. A long
# journal is shortened to fit, with a pointer to INDEX.md for the rest.
# journal.sh calls this after `vellum resume`.
print_project_context() {
  local budget="${2:-$CONTEXT_BUDGET}" full pointer
  [ -n "${1:-}" ] && set_project "$1"

  # A private journal from an earlier version gains any new starter files,
  # such as the overview and preferences, and a current index. A kit's
  # design-journal/ is committed to git, so it is only ever read here.
  if [ "$JOURNAL_NAME" = ".vellum" ] && [ -d "$JOURNAL" ] && [ ! -f "$JOURNAL/.paused" ]; then
    seed_journal "$JOURNAL"
    build_index "$JOURNAL"
  fi

  full="$(project_block full)"
  if [ "$(printf '%s\n' "$full" | json_size)" -le "$budget" ]; then
    printf '%s\n' "$full"
    return 0
  fi
  pointer="(The journal is long, so parts of it were shortened here. Read $JOURNAL/INDEX.md for everything in it, and open entries from there when they are needed.)"
  project_block tight | fit_to_budget "$((budget - $(printf '\n%s\n' "$pointer" | json_size)))"
  echo
  echo "$pointer"
}

# The name the other files use.
project_context() {
  print_project_context "$@"
}

# The project block at one of two lengths: "full", or "tight" for a journal
# too long to show whole.
project_block() {
  local level="$1" recap
  recap="$(last_time_line)"

  if [ -f "$JOURNAL/.paused" ]; then
    echo "Vellum is paused for this project ($ROOT). Write nothing to the journal in $JOURNAL_NAME/ unless the person asks you to resume (\`\"$VELLUM_BIN_PATH\" resume\`). You may still read it to answer questions about the project."
    [ -n "$recap" ] && printf '\n%s\n' "$recap"
    return 0
  fi

  [ -n "$recap" ] && printf '%s\n\n' "$recap"
  port_guidance
  journal_instructions
  echo
  echo "# Journal for $(basename "$ROOT")"

  if [ -f "$JOURNAL/overview.md" ] && ! grep -q '^Not written yet' "$JOURNAL/overview.md"; then
    echo
    echo "## Overview ($JOURNAL_NAME/overview.md)"
    echo
    if [ "$level" = "full" ]; then head_with_note "$JOURNAL/overview.md" 120; else short_text "$JOURNAL/overview.md" 25; fi
  else
    # No curated overview yet, so the latest logbook is the best summary.
    local latest
    latest=$(ls -1 "$JOURNAL"/logbook/*.md 2>/dev/null | sort | tail -1)
    if [ -n "$latest" ]; then
      echo
      echo "## Most recent logbook entry ($JOURNAL_NAME/logbook/$(basename "$latest"))"
      echo
      if [ "$level" = "full" ]; then head_with_note "$latest" 150; else short_text "$latest" 25; fi
    fi
  fi

  if grep -q '^## ' "$JOURNAL/preferences.md" 2>/dev/null; then
    echo
    if [ "$level" = "full" ]; then
      echo "## What the person likes and rejects ($JOURNAL_NAME/preferences.md)"
      echo
      head_with_note "$JOURNAL/preferences.md" 80
    else
      echo "## Topics the person has preferences about (read $JOURNAL_NAME/preferences.md before proposing a design or approach)"
      echo
      grep -E '^## ' "$JOURNAL/preferences.md" | head -20
    fi
  fi

  if grep -q '^### ' "$JOURNAL/$LESSONS" 2>/dev/null; then
    echo
    echo "## Lessons by topic ($JOURNAL_NAME/$LESSONS has the full text)"
    echo
    if [ "$level" = "full" ]; then
      grep -E '^(## |### )' "$JOURNAL/$LESSONS" | head -80
    else
      grep -E '^### ' "$JOURNAL/$LESSONS" | head -12
    fi
  fi

  echo
  echo "## Everything in the journal ($JOURNAL_NAME/INDEX.md). Open entries only when needed."
  echo
  if [ "$level" = "full" ]; then
    journal_index | head -150
  else
    journal_index | short_index
  fi

  if [ "$level" = "full" ]; then
    linked_context
  else
    linked_context | head -40
  fi
}

# The first N lines of a file without its frontmatter, with a note if cut.
short_text() {
  local file="$1" max="$2" total
  total=$(strip_frontmatter "$file" | wc -l | tr -d ' ')
  strip_frontmatter "$file" | head -n "$max"
  [ "$total" -gt "$max" ] && printf '\n(Cut at %s of %s lines. Read %s for the rest.)\n' "$max" "$total" "$file"
  return 0
}

# The journal instructions, with the journal's folder and commands filled in.
journal_instructions() {
  local curator
  if [ "$(config_get background on)" = "on" ]; then
    curator="A curator organises everything when the session ends."
  else
    curator="The end-of-session curator is switched off (\`vellum config background off\`), so nothing tidies the journal after the session: keep \`$JOURNAL_NAME/overview.md\` true as things change."
  fi
  sed -e "s|{{VELLUM_BIN}}|$(sed_escape "$VELLUM_BIN_PATH")|g" -e "s|{{J}}|$JOURNAL_NAME|g" \
    -e "s|{{LESSONS}}|$LESSONS|g" -e "s|{{CURATOR}}|$(sed_escape "$curator")|g" "$TEMPLATES/instructions.md"
}

# The journal's index without its frontmatter. A kit's design-journal/ with
# no INDEX.md gets a list made on the spot, so nothing is written to it.
journal_index() {
  local lines
  if [ -f "$JOURNAL/INDEX.md" ]; then
    strip_frontmatter "$JOURNAL/INDEX.md" | grep -v '^# Index' | cat -s | sed '1{/^$/d;}'
    return 0
  fi
  lines="$(index_lines "$JOURNAL" decisions)"
  [ -n "$lines" ] && printf '## Decisions\n\n%s\n\n' "$lines"
  lines="$(index_lines "$JOURNAL" experiments)"
  [ -n "$lines" ] && printf '## Experiments\n\n%s\n\n' "$lines"
  lines="$(index_lines "$JOURNAL" logbook | sort -r | head -30)"
  [ -n "$lines" ] && printf '## Logbook, newest first\n\n%s\n' "$lines"
  return 0
}

# A shorter index for a long journal: entry names without their summaries,
# the last ten logbook days and the last four weekly round-ups.
short_index() {
  awk '
    /^## / { section = $0; n = 0; print; next }
    /^- / {
      n++
      if (section ~ /^## Logbook/ && n > 10) { if (n == 11) print "- ...older days are listed in INDEX.md"; next }
      if (section ~ /^## Weekly/ && n > 4) next
      if (section ~ /^## Artefacts/ && n > 10) next
      if (section ~ /^## (Decisions|Experiments|Weekly|Logbook)/ && $0 !~ /^- \.\.\./) {
        if (!sub(/\): .*$/, ")")) sub(/`: .*$/, "`")
      }
    }
    { print }'
}

# The project's own port, so its local server never clashes with another's.
project_port() {
  field "$(reg_line "$(reg_name_for_path "$ROOT")")" 3
}

port_guidance() {
  local port
  port="$(project_port)"
  [ -n "$port" ] || return 0
  cat <<EOF
## This project's port is $port

Start its local server on port $port (for example \`PORT=$port npm run dev\`, \`npm run dev -- --port $port\` or \`python3 -m http.server $port\`), and give the address http://localhost:$port. Do not mention the port otherwise.

EOF
}

# One line to put the person back in the picture: what happened last time and
# what is next, from the overview, or the latest logbook if there is no
# overview yet. Prints nothing if the journal has neither.
last_time_line() {
  local overview="$JOURNAL/overview.md" last="" next="" latest
  if [ -f "$overview" ] && ! grep -q '^Not written yet' "$overview"; then
    last="$(awk '/^## Recent sessions/ {want = 1; next} want && /^## / {exit} want && /^[-*] / {sub(/^[-*] +/, ""); print; exit}' "$overview")"
    next="$(awk '/^## Next steps/ {want = 1; next} want && /^## / {exit} want && /^[-*] / {sub(/^[-*] +/, ""); print; exit}' "$overview")"
  fi
  # Overviews from the project kit list goals in place of next steps.
  if [ -z "$next" ] && [ -f "$overview" ]; then
    next="$(awk '/^## Active goals/ {want = 1; next} want && /^## / {exit} want && /^[-*] / {sub(/^[-*] +/, ""); print; exit}' "$overview")"
  fi
  if [ -z "$last" ]; then
    latest=$(ls -1 "$JOURNAL"/logbook/*.md 2>/dev/null | sort | tail -1)
    [ -n "$latest" ] || return 0
    # The first section heading, or else the first sentence of the entry.
    last="$(strip_frontmatter "$latest" | awk '
      /^## / { sub(/^## +/, ""); print; exit }
      /^#/ || !NF || /^---/ { next }
      { line = $0; if (match(line, /\. /)) line = substr(line, 1, RSTART); print line; exit }')"
    [ -n "$last" ] || return 0
    last="$(basename "$latest" .md): $last"
  fi
  # Checklist markers, such as "[ ]" and "[x]", mean nothing in a sentence.
  last="$(printf '%s' "$last" | sed -E 's/^\[[ xX]\][[:space:]]*//')"
  next="$(printf '%s' "$next" | sed -E 's/^\[[ xX]\][[:space:]]*//')"
  # "2026-10-16 — Started the project" reads better as "16 Oct: Started the
  # project". Any dash or colon after the date goes.
  last="$(printf '%s' "$last" | sed -E 's/^\*?\*?([0-9]{4})-([0-9]{2})-([0-9]{2})\*?\*?[[:space:]]*(:|—|–|-)?[[:space:]]*/\3-\2 /; s/^0//' | awk '{
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", m, " ")
    if (match($1, /^[0-9]+-[0-9][0-9]$/)) { split($1, d, "-"); $1 = d[1] " " m[d[2] + 0] ":" }
    print }')"
  printf 'Last time, %s' "$(shorten "$last" 100)"
  [ -n "$next" ] && printf ' Next: %s' "$(shorten "$next" 80)"
  echo
}

# Shorten text to about N characters at a word boundary, ending with a full
# stop or an ellipsis.
shorten() {
  printf '%s' "$1" | awk -v n="$2" '{
    t = $0
    if (length(t) > n) {
      t = substr(t, 1, n)
      sub(/[[:space:]]+[^[:space:]]*$/, "", t)
      sub(/[,;:.[:space:]]+$/, "", t)
      t = t "…"
    } else if (t !~ /[.!?…]$/) {
      t = t "."
    }
    print t
  }'
}

# Background from linked projects: an archive's summary and lessons, or a live
# project's overview and lesson titles.
linked_context() {
  local imp archive line dir
  [ -f "$JOURNAL/.imports" ] || return 0
  while IFS= read -r imp; do
    [ -n "$imp" ] || continue
    case "$imp" in
      project:*)
        line="$(reg_line "${imp#project:}")"
        [ -n "$line" ] || continue
        dir="$(field "$line" 2)"
        (
          set_project "$dir"
          [ -d "$JOURNAL" ] || exit 0
          echo
          echo "## Background from the linked project \"${imp#project:}\" ($JOURNAL)"
          echo
          [ -f "$JOURNAL/overview.md" ] && strip_frontmatter "$JOURNAL/overview.md" | head -60
          if grep -q '^### ' "$JOURNAL/$LESSONS" 2>/dev/null; then
            echo
            echo "Its lessons ($JOURNAL/$LESSONS):"
            grep -E '^### ' "$JOURNAL/$LESSONS" | head -40
          fi
        )
        ;;
      *)
        archive="$LIBRARY/${imp}_archive.md"
        [ -f "$archive" ] || continue
        echo
        echo "## Background from the past project \"$imp\""
        echo
        awk '/^## / {keep = ($0 == "## Summary" || $0 == "## Lessons learned")} keep {print}' "$archive"
        ;;
    esac
  done <"$JOURNAL/.imports"
}

# A folder worth offering a journal to: a git repository or anything in the
# projects folder. Saves asking about Downloads and the like. In a git
# worktree, .git is a file, not a folder.
looks_like_project() {
  local root="$1"
  [ -e "$root/.git" ] && return 0
  case "$root/" in "$(projects_dir)"/*) return 0 ;; esac
  return 1
}

# What changed in a journal since a marker file was made, in a few words, such
# as "1 decision, lessons and the overview". Prints nothing if nothing changed.
journal_changes() {
  local journal="$1" marker="$2" n parts="" last=""
  add_part() { if [ -n "$last" ]; then parts="${parts:+$parts, }$last"; fi; last="$1"; }
  n=$(find "$journal/decisions" -name '*.md' -newer "$marker" 2>/dev/null | grep -c .)
  [ "$n" -gt 0 ] && add_part "$n decision$( [ "$n" -gt 1 ] && echo s)"
  n=$(find "$journal/experiments" -name '*.md' -newer "$marker" 2>/dev/null | grep -c .)
  [ "$n" -gt 0 ] && add_part "$n experiment$( [ "$n" -gt 1 ] && echo s)"
  [ -n "$(find "$journal/$LESSONS" -newer "$marker" 2>/dev/null)" ] && add_part "lessons"
  [ -n "$(find "$journal/preferences.md" -newer "$marker" 2>/dev/null)" ] && add_part "preferences"
  [ -n "$(find "$journal/weekly" -name '*.md' -newer "$marker" 2>/dev/null)" ] && add_part "a weekly round-up"
  [ -n "$(find "$journal/overview.md" -newer "$marker" 2>/dev/null)" ] && add_part "the overview"
  if [ -n "$parts" ]; then
    echo "$parts and $last"
  else
    echo "$last"
  fi
}

# Leave a one-line message for the next session about what the curator did.
# $2 is what changed; $3 is "failed" if the curator did not finish.
save_notice() {
  local root="$1" summary="$2" outcome="${3:-}" name text
  name="$(reg_name_for_path "$root")"
  name="${name:-$(basename "$root")}"
  if [ "$outcome" = "failed" ]; then
    text="The curator could not update $name's journal after your last session. Say \"tidy the journal\" in $name to try again."
  elif [ -n "$summary" ]; then
    text="Journal updated after your last session: $name, $summary. Say \"undo the journal update\" to reverse it."
  else
    return 0
  fi
  mkdir -p "$VELLUM_HOME/notices"
  printf '%s\n' "$text" >"$VELLUM_HOME/notices/$(__sanitize "$root")"
}

# The waiting messages for a project, or for every project from the home
# folder, joined into one line. Shown once, then deleted.
take_notices() {
  local root="$1" f out=""
  [ -d "$VELLUM_HOME/notices" ] || return 0
  for f in "$VELLUM_HOME"/notices/*; do
    [ -f "$f" ] || continue
    if [ "$root" = "$HOME_P" ] || [ "$root" = "$(projects_dir)" ] || [ "$(basename "$f")" = "$(__sanitize "$root")" ]; then
      out="${out:+$out
}$(cat "$f")"
      rm -f "$f"
    fi
  done
  [ -n "$out" ] && echo "$out"
}

# Print a JSON string, escaped. Uses jq or python3; fails if neither is there.
# Letters outside ASCII stay as they are, so the size json_size counts holds.
json_string() {
  if command -v jq >/dev/null 2>&1; then
    jq -Rs . 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False))' 2>/dev/null
  else
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Session start
# ---------------------------------------------------------------------------

# The SessionStart hook. Claude gets the context. The person sees a one-line
# message if the curator updated a journal since their last session.
hook_session_start() {
  is_helper_session && return 0
  local input="" context message cwd root source recap budget ctx_json msg_json
  [ -t 0 ] || input="$(cat || true)"
  cwd="$(json_field "$input" cwd)"
  root="$(project_root "${cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}")"
  source="$(json_field "$input" source)"
  message="$(take_notices "$root")"
  if [ "$source" = "startup" ] || [ -z "$source" ]; then
    recap="$(
      set_project "$root"
      [ -d "$JOURNAL" ] && [ ! -f "$JOURNAL/.paused" ] && [ "$root" != "$HOME_P" ] && last_time_line
    )"
    [ -n "$recap" ] && message="$recap${message:+
$message}"
  fi
  # Commands Claude runs in this session see the project's port as PORT, which
  # most web servers use by themselves.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    local port
    port="$(set_project "$root"; project_port)"
    [ -n "$port" ] && echo "export PORT=$port" >>"$CLAUDE_ENV_FILE"
  fi
  # The message and the JSON around it share the budget with the context.
  budget=$CONTEXT_BUDGET
  [ -n "$message" ] && budget=$((budget - $(printf '%s' "$message" | json_size) - 100))
  context="$(printf '%s' "$input" | session_start_context "$budget")"
  if [ -n "$message" ] && ctx_json="$(printf '%s' "$context" | json_string)" && msg_json="$(printf '%s' "$message" | json_string)"; then
    printf '{"systemMessage":%s,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$msg_json" "$ctx_json"
  else
    printf '%s\n' "$context"
  fi
}

# The plain-English commands for running projects. Without a session id, the
# --session parts are left out.
projects_commands() {
  local session="$1"
  if [ -n "$session" ]; then
    sed -e "s|{{VELLUM_BIN}}|$(sed_escape "$VELLUM_BIN_PATH")|g" -e "s|{{SESSION}}|$(sed_escape "$session")|g" "$TEMPLATES/projects.md"
  else
    sed -e "s|{{VELLUM_BIN}}|$(sed_escape "$VELLUM_BIN_PATH")|g" -e 's| Add `--session {{SESSION}}` where shown\.||' \
      -e 's| --session {{SESSION}}||g' "$TEMPLATES/projects.md"
  fi
}

# A note when projects from the earlier project kit are not on the list and
# the list has nothing else on it. The folder this session is in does not
# count, because session start adds it to the list.
kit_import_note() {
  local pdir="$1" n
  [ -n "$(kit_ports)" ] || return 0
  if [ -s "$REGISTRY" ] && [ -n "$(awk -F'\t' -v r="$ROOT" 'NF && $2 != r' "$REGISTRY")" ]; then
    return 0
  fi
  n="$(kit_project_count)"
  if [ "$ROOT" = "$pdir/$(basename "$ROOT")" ] && kit_ports | cut -d "$TAB" -f1 | grep -qxF "$(basename "$ROOT")"; then
    n=$((n - 1))
  fi
  [ "$n" -gt 0 ] || return 0
  cat <<EOF
Vellum note: the earlier project kit has $n project$( [ "$n" -ne 1 ] && echo s) in $pdir that $( [ "$n" -ne 1 ] && echo "are" || echo "is") not on the project list yet. In your next reply, offer once to bring $( [ "$n" -ne 1 ] && echo them || echo it) in with \`"$VELLUM_BIN_PATH" import-kit\`.

EOF
}

# Up to 40 active projects, most recent work first, read from the project
# list in one pass. Never writes the list, so it stays quick with hundreds of
# projects. `vellum list` shows them all.
quick_project_list() {
  local name dir port shape j f last total summary when
  if [ ! -s "$REGISTRY" ]; then
    echo "There are no projects on the list yet."
    return 0
  fi
  total=$(awk -F'\t' '$1 != "" && $4 != "closed" {n++} END {print n + 0}' "$REGISTRY")
  # Empty columns become "-", because read would merge neighbouring tabs.
  awk -F'\t' -v OFS='\t' '$1 != "" && $4 != "closed" {print $1, $2, ($3 == "" ? "-" : $3), ($7 == "" ? "-" : $7)}' "$REGISTRY" |
  while IFS="$TAB" read -r name dir port shape; do
    j="$dir/.vellum"
    [ -d "$dir/design-journal" ] && [ ! -d "$j" ] && j="$dir/design-journal"
    # Logbook files are named by date and globs come back sorted, so the last
    # one is the newest.
    last=""
    for f in "$j"/logbook/*.md; do [ -f "$f" ] && last="${f##*/}"; done
    last="${last%.md}"
    printf '%s\t%s\t%s\t%s\t%s\n' "${last:-0000-00-00}" "$name" "$port" "$j" "$shape"
  done | sort -r | head -40 | while IFS="$TAB" read -r last name port j shape; do
    when="no sessions yet"
    [ "$last" != "0000-00-00" ] && when="last worked on $last"
    [ "$shape" = "-" ] && shape=""
    [ "$port" = "-" ] && port="none"
    echo "${shape:+$shape }$name  (port $port, $when)"
    summary="$(project_summary "$j")"
    [ -n "$summary" ] && echo "    $summary"
  done
  if [ "$total" -gt 40 ]; then
    echo "($((total - 40)) more active projects are not shown. Run \`\"$VELLUM_BIN_PATH\" list\` to see them all.)"
  fi
  return 0
}

# Prints context for Claude at the start of every session: notes, then what
# is specific to this folder, then the commands for running projects. The
# whole stays within $1 JSON characters.
session_start_context() {
  local budget="${1:-$CONTEXT_BUDGET}" input="" cwd session name port notes="" commands pdir
  local session_arg="" header="" left offer
  [ -t 0 ] || input="$(cat || true)"
  cwd="$(json_field "$input" cwd)"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  # Without a session id, nothing is recorded against a session.
  session="$(json_field "$input" session_id)"
  [ -n "$session" ] && session_arg=" --session $session"

  if has_legacy_install; then
    notes="${notes}Vellum note: the old curl version of Scribe (the earlier name of Vellum) is still installed alongside the plugin, so both may write journals. In your next reply, tell the person this once and offer to run \`\"$VELLUM_BIN_PATH\" remove-old-install\`, which removes the old hooks, commands and PATH line and keeps their archived projects.

"
  fi
  if theme_update_waiting; then
    notes="${notes}Vellum note: a new version of the Vellum Terminal theme has arrived. In your next reply, offer once to apply it with \`\"$VELLUM_BIN_PATH\" theme\`. Say that it replaces the Vellum profile in Terminal, so any colours they changed in Terminal's own settings are lost. If they say no, run \`\"$VELLUM_BIN_PATH\" theme skip\`.

"
  fi

  commands="$(projects_commands "$session")"
  pdir="$(projects_dir)"
  set_project "$(project_root "$cwd")"
  notes="$notes$(kit_import_note "$pdir")"

  # Room left for the part about this folder.
  left=$((budget - $(printf '%s\n\n%s\n' "$notes" "$commands" | json_size) - 50))

  if [ "$ROOT" = "$HOME_P" ] || [ "$ROOT" = "$pdir" ]; then
    printf '%s' "$notes"
    { echo "## Their projects, most recent first"; echo; quick_project_list; } |
      fit_to_budget "$((left - 200))"
    echo
    printf '%s\n' "$commands"
    log "session-start: project list loaded in $ROOT"
    return 0
  fi

  if [ ! -d "$JOURNAL" ]; then
    offer=""
    if has_legacy_journal "$ROOT"; then
      offer="Vellum: this project ($ROOT) has a journal in journal/ from the old curl version of Scribe. In your next reply, offer once to move it with \`\"$VELLUM_BIN_PATH\" migrate\`. That moves it to .vellum/, removes the Scribe block from CLAUDE.md and the journal/ line from .gitignore, and keeps it out of git another way. Until then, keep following the journal instructions in CLAUDE.md."
    elif ! is_declined "$ROOT" && looks_like_project "$ROOT"; then
      offer="Vellum is installed but this folder ($ROOT) is not one of their projects yet.

In your next reply, ask once whether to add it. Suggested wording: \"Vellum can add this folder to your projects and keep a private journal of it, so I remember what we decided next time. Add it? (yes / no / not now)\".

- Yes: run \`\"$VELLUM_BIN_PATH\" adopt$session_arg\` and tell them what it printed.
- No: run \`\"$VELLUM_BIN_PATH\" init --decline\`, so you do not ask again.
- Not now, or no clear answer: do nothing. You will ask again next session.

Do not ask again this session once they have answered."
    fi
    printf '%s' "$notes"
    [ -n "$offer" ] && printf '%s\n\n' "$offer"
    printf '%s\n' "$commands"
    return 0
  fi

  # A folder with a journal is a project: make sure it is on the list.
  if [ -z "$(reg_name_for_path "$ROOT")" ]; then
    name="$(free_name "$(slugify "$(basename "$ROOT")")")"
    port="$(kit_ports | awk -F'\t' -v n="$(basename "$ROOT")" '$1 == n {print $2; exit}')"
    reg_add "$name" "$ROOT" "${port:-$(next_port)}"
  fi
  [ -n "$session" ] && remember_session "$session" "$ROOT"

  if has_kit_hooks "$ROOT"; then
    header="Vellum note: this project still has the earlier project kit's own hooks, so its journal is being written twice. In your next reply, offer once to switch it over fully with \`\"$VELLUM_BIN_PATH\" adopt$session_arg\`. That removes the kit's two hooks from .claude/settings.json (keeping a backup) and stops its weekly job. The journal stays where it is.

"
  fi
  header="$header# Current project: $(reg_name_for_path "$ROOT") ($ROOT)
"
  left=$((left - $(printf '%s\n' "$header" | json_size)))

  printf '%s' "$notes"
  printf '%s\n' "$header"
  print_project_context "" "$left"
  echo
  printf '%s\n' "$commands"
  log "session-start: context loaded for $ROOT"
}

# ---------------------------------------------------------------------------
# Session end and the curator
#
# Claude Code gives a SessionEnd hook about a second and a half, whatever
# timeout the plugin asks for. So the hook only records the session as a job
# in ~/.vellum/.state/queue/ and starts one curator worker, detached from
# Claude Code. The worker condenses each session and runs the curator on
# every project it touched, one job after another, until the queue is empty.
#
# ~/.vellum/.state/lock      held by the running worker (its process id is
#                            in lock/pid); a job queued while it runs waits
#                            for it
# <journal>/.state/lock      one curator per project at a time, shared with
#                            `vellum curate` and `vellum undo` in journal.sh
# ---------------------------------------------------------------------------

curator_queue() { echo "$VELLUM_HOME/.state/queue"; }
curator_lock() { echo "$VELLUM_HOME/.state/lock"; }

# Is a worker lock held by a process that is still running?
lock_alive() {
  local lock="$1" pid
  pid="$(cat "$lock/pid" 2>/dev/null)"
  if [ -n "$pid" ]; then
    kill -0 "$pid" 2>/dev/null
    return
  fi
  # No process id yet: it is being taken right now, unless it is old.
  [ -n "$(find "$lock" -maxdepth 0 -mmin -2 2>/dev/null)" ]
}

# Take the worker lock. A lock is only cleared once it is confirmed stale,
# because the process that took it has gone.
take_lock() {
  local lock="$1" stale
  mkdir -p "$(dirname "$lock")" 2>/dev/null || return 1
  if mkdir "$lock" 2>/dev/null; then
    echo "$$" >"$lock/pid"
    return 0
  fi
  lock_alive "$lock" && return 1
  # Move the stale lock aside in one step, so two processes cannot both clear
  # it, then check it really was stale.
  stale="$lock.stale.$$"
  mv "$lock" "$stale" 2>/dev/null || return 1
  if lock_alive "$stale"; then
    [ -e "$lock" ] || mv "$stale" "$lock" 2>/dev/null
    rm -rf "$stale"
    return 1
  fi
  rm -rf "$stale"
  log "curator: cleared a stale lock"
  mkdir "$lock" 2>/dev/null || return 1
  echo "$$" >"$lock/pid"
}

# The SessionEnd hook. Records the session as a job and starts the curator
# worker. Does nothing slow, so it always finishes in time.
hook_session_end() {
  is_helper_session && return 0

  local input="" cwd transcript session sfile="" queue job tmp
  [ -t 0 ] || input="$(cat || true)"
  cwd="$(json_field "$input" cwd)"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  transcript="$(json_field "$input" transcript_path)"
  session="$(json_field "$input" session_id)"
  [ -n "$session" ] || [ -z "$transcript" ] || session="$(basename "$transcript" .jsonl)"
  [ -n "$session" ] && sfile="$SESSIONS/$(__sanitize "$session")"

  if [ "$(config_get background on)" != "on" ]; then
    rm -f ${sfile:+"$sfile"}
    log "session-end: background curator is off"
    return 0
  fi
  if ! command -v claude >/dev/null 2>&1; then
    rm -f ${sfile:+"$sfile"}
    log "session-end: claude not on PATH"
    return 0
  fi
  if [ -z "$transcript" ]; then
    rm -f ${sfile:+"$sfile"}
    log "session-end: no transcript"
    return 0
  fi

  # The job holds everything the worker needs, including the projects this
  # session opened. The session's own record goes only once the job is safe.
  queue="$(curator_queue)"
  mkdir -p "$queue" 2>/dev/null || return 0
  job="$queue/$(date '+%Y%m%d-%H%M%S')-$$-$(__sanitize "$session").job"
  tmp="$queue/.new-$$"
  if {
    printf 'cwd=%s\n' "$cwd"
    printf 'transcript=%s\n' "$transcript"
    printf 'session=%s\n' "$session"
    [ -f "$sfile" ] && sed 's/^/root=/' "$sfile"
    true
  } >"$tmp" 2>/dev/null && mv "$tmp" "$job"; then
    rm -f ${sfile:+"$sfile"}
    log "session-end: queued $session for the curator"
  else
    rm -f "$tmp"
    log "session-end: could not queue $session"
    return 0
  fi
  start_curator_worker
}

# Start the curator worker unless one is already running, in which case it
# picks up the new job before it stops. The worker gets its own session
# (setsid), so closing the Terminal window does not stop it.
start_curator_worker() {
  local lock pid
  lock="$(curator_lock)"
  if ! take_lock "$lock"; then
    log "session-end: a curator is already running, so the session waits in the queue"
    return 0
  fi
  if command -v perl >/dev/null 2>&1; then
    perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV or exit 1' "$VELLUM_BIN_PATH" hook curator </dev/null >/dev/null 2>&1 3>&- &
  else
    nohup "$VELLUM_BIN_PATH" hook curator </dev/null >/dev/null 2>&1 3>&- &
  fi
  pid=$!
  # The worker records itself too; this covers the moment before it starts.
  [ "$(cat "$lock/pid" 2>/dev/null)" = "$$" ] && echo "$pid" >"$lock/pid" 2>/dev/null
  return 0
}

# The oldest job in the queue, or nothing.
next_job() {
  local f
  for f in "$1"/*.job; do
    [ -f "$f" ] && { echo "$f"; return 0; }
  done
  return 0
}

# The curator worker (`vellum hook curator`). Works through the queue, then
# lets the lock go. If the worker is stopped, its locks go with it.
curator_worker() {
  local lock queue job
  lock="$(curator_lock)"
  queue="$(curator_queue)"
  trap '' HUP
  # The hook took the lock for this worker.
  if [ -d "$lock" ]; then echo "$$" >"$lock/pid"; else take_lock "$lock" || return 0; fi
  trap 'rm -rf "$lock"' EXIT
  trap 'exit 1' INT TERM
  while :; do
    while job="$(next_job "$queue")" && [ -n "$job" ]; do
      # Each job runs in its own subshell, which lets its project's lock go
      # if it is stopped part way.
      (
        PROJECT_LOCK=""
        trap '[ -n "$PROJECT_LOCK" ] && rm -rf "$PROJECT_LOCK"' EXIT
        trap 'exit 1' INT TERM
        run_job "$job"
      )
      # A job that cannot be removed would run for ever.
      rm -f "$job" 2>/dev/null && [ ! -f "$job" ] || { log "curator: could not remove $job"; break; }
    done
    trap - EXIT
    rm -rf "$lock"
    # A session may have been queued just as the lock was let go.
    [ -n "$(next_job "$queue")" ] || break
    take_lock "$lock" || break
    trap 'rm -rf "$lock"' EXIT
  done
  return 0
}

# Does the session belong to a paused project, or a folder where the person
# said no? Then nothing of it is kept, not even for recall.
session_is_private() {
  local root
  while IFS= read -r root; do
    [ -n "$root" ] && [ "$root" != "$HOME_P" ] || continue
    is_declined "$root" && return 0
    set_project "$root"
    [ -f "$JOURNAL/.paused" ] && return 0
  done <<EOF
$1
EOF
  return 1
}

# Add a conversation to recall. It is written to one side first and moved in
# whole, so a search running at the same moment never reads half a file.
recall_cache_quietly() {
  local transcript="$1" id cache side
  id="$(basename "$transcript" .jsonl)"
  cache="$(recall_dir)/$id.txt"
  [ -f "$cache" ] && [ ! "$transcript" -nt "$cache" ] && return 0
  side="$VELLUM_HOME/.state/recall-$$"
  mkdir -p "$(recall_dir)" "$side/recall" || return 0
  ( VELLUM_HOME="$side"; recall_cache_one "$transcript" ) || true
  [ -f "$side/recall/$id.txt" ] && mv "$side/recall/$id.txt" "$cache"
  rm -rf "$side"
}

# Work through one queued session: keep recall up to date, then run the
# curator on every project the session touched.
run_job() {
  local job="$1" line cwd="" transcript="" session="" roots="" size others="no" root count
  while IFS= read -r line; do
    case "$line" in
      cwd=*) cwd="${line#cwd=}" ;;
      transcript=*) transcript="${line#transcript=}" ;;
      session=*) session="${line#session=}" ;;
      root=*) roots="$roots${line#root=}
" ;;
    esac
  done <"$job"

  { [ -n "$transcript" ] && [ -f "$transcript" ]; } || { log "curator: no transcript for $session"; return 0; }
  size=$(wc -c <"$transcript" | tr -d ' ')
  [ "$size" -ge 2000 ] || { log "curator: transcript too short ($size bytes) for $session"; return 0; }

  # The projects this session touched: the folder it ran in, plus any it opened.
  roots="$(printf '%s\n%s' "$(project_root "$cwd")" "$roots" | awk 'NF && !seen[$0]++')"

  # Keep recall up to date with the conversation that just ended, unless it
  # belongs to a paused or declined project. Nothing is recorded for those, so
  # recall picks the conversation up if journaling is turned back on.
  if session_is_private "$roots"; then
    log "curator: recall skipped for $session (paused or declined)"
  else
    recall_cache_quietly "$transcript"
  fi

  count=$(printf '%s\n' "$roots" | grep -c .)
  [ "$count" -gt 1 ] && others="yes"
  [ "$(project_root "$cwd")" = "$HOME_P" ] && others="yes"

  while IFS= read -r root; do
    [ -n "$root" ] || continue
    [ "$root" = "$HOME_P" ] && continue
    curate_root "$root" "$transcript" "$session" "$size" "$others"
  done <<EOF
$roots
EOF
}

# Take a project's curator lock, waiting while `vellum curate` or `vellum undo`
# holds it. A lock older than 30 minutes is stale. Gives up if the journal goes.
take_project_lock() {
  local lock="$JOURNAL/.state/lock" waited=0
  while :; do
    [ -d "$JOURNAL" ] || return 1
    mkdir -p "$JOURNAL/.state" 2>/dev/null || return 1
    if mkdir "$lock" 2>/dev/null; then
      PROJECT_LOCK="$lock"
      return 0
    fi
    if [ -z "$(find "$lock" -maxdepth 0 -mmin -30 2>/dev/null)" ]; then
      rm -rf "$lock"
      log "curator: cleared a stale lock in $ROOT"
      continue
    fi
    [ "$waited" -eq 0 ] && log "curator: waiting for another curator to finish in $ROOT"
    waited=$((waited + 1))
    [ "$waited" -le 1800 ] || return 1
    sleep 1
  done
}

# Run the curator on one project for a session. Reads only the session and
# the project, and writes only inside the project's journal. It has no shell
# and no web access.
curate_root() {
  local root="$1" transcript="$2" session="$3" size="$4" others="$5"
  local state_dir state last condensed note extra_read="" prompt_file marker
  set_project "$root"
  [ -d "$JOURNAL" ] || return 0
  [ -f "$JOURNAL/.paused" ] && { log "curator: paused in $ROOT"; return 0; }

  take_project_lock || { log "curator: could not take the lock in $ROOT"; return 0; }
  if [ -f "$JOURNAL/.state/skip-next" ]; then
    rm -f "$JOURNAL/.state/skip-next"
    log "curator: skipped after an undo in $ROOT"
    rm -rf "$PROJECT_LOCK"; PROJECT_LOCK=""
    return 0
  fi

  state_dir="$JOURNAL/.state"
  state="$state_dir/$(__sanitize "$session")"
  # Skip a transcript that has not grown since the curator last read it.
  last=$(cat "$state" 2>/dev/null || echo 0)
  if [ "$size" -le "${last:-0}" ]; then
    log "curator: nothing new in $session for $ROOT"
    rm -rf "$PROJECT_LOCK"; PROJECT_LOCK=""
    return 0
  fi

  # The curator reads a condensed copy of the session, about a hundredth of the
  # size. If that cannot be made, it reads the raw transcript instead.
  condensed="$state_dir/session-$(__sanitize "$session").txt"
  if condense_transcript "$transcript" "$condensed"; then
    note="A Claude Code session has just ended. Its conversation is in ./$JOURNAL_NAME/.state/$(basename "$condensed"). Each line starts with PERSON (the person), CLAUDE (Claude's reply), ACTION (a tool Claude used, with its file or command) or FAILED (an action that went wrong)."
  else
    condensed=""
    note="A Claude Code session has just ended. Its full transcript, in JSON lines, is at $transcript. Read what the person and Claude said, and skip the rest."
    extra_read="Read(/$transcript)"
  fi
  if [ "$others" = "yes" ]; then
    note="$note

The session also covered other projects, or started outside this one. Record only the work on \"$(basename "$ROOT")\". If there was none, change nothing and reply \"Nothing to record\"."
  fi
  prompt_file="$state_dir/prompt.txt"
  write_curator_prompt "$note" "$prompt_file"

  log "curator: started for $session in $ROOT"
  snapshot_journal
  marker="$state_dir/started"
  : >"$marker"
  sleep 1
  if run_curator "$prompt_file" "$extra_read" >>"$state_dir/helper.log" 2>&1; then
    echo "$size" >"$state"
    save_notice "$ROOT" "$(journal_changes "$JOURNAL" "$marker")"
  else
    save_notice "$ROOT" "" failed
  fi
  rm -f "$marker" "$prompt_file" ${condensed:+"$condensed"}
  build_index "$JOURNAL"
  rm -rf "$PROJECT_LOCK"
  PROJECT_LOCK=""
}

cmd_hook() {
  case "${1:-}" in
    session-start) hook_session_start ;;
    session-end)   hook_session_end ;;
    curator)       curator_worker ;;
    *) die "unknown hook '${1:-}'" ;;
  esac
  # A hook must never block or fail the user's session.
  return 0
}
