#!/bin/bash
# Sourced by bin/scribe. Written for bash 3.2+.
# shellcheck shell=bash

# The SessionStart and SessionEnd hooks, and the project context they share
# with `scribe open` and `scribe new`.

# Print the journal instructions and the journal itself for the project that
# set_project chose. Used at session start and when a project is opened.
project_context() {
  if [ -f "$JOURNAL/.paused" ]; then
    echo "Terminal Scribe is paused for this project ($ROOT). Do not write to the journal unless the person asks you to resume (\`\"$SCRIBE_BIN_PATH\" resume\`)."
    return 0
  fi

  port_guidance
  sed -e "s|{{SCRIBE_BIN}}|$SCRIBE_BIN_PATH|g" -e "s|{{J}}|$JOURNAL_NAME|g" -e "s|{{LESSONS}}|$LESSONS|g" "$TEMPLATES/instructions.md"
  echo
  echo "# Journal for $(basename "$ROOT")"

  # Journals from earlier versions gain any new starter files, such as the
  # overview and preferences, and the index is rebuilt so it is current.
  seed_journal "$JOURNAL"
  build_index "$JOURNAL"

  if grep -q '^Not written yet' "$JOURNAL/overview.md" 2>/dev/null; then
    # No curated overview yet, so the latest logbook is the best summary.
    local latest
    latest=$(ls -1 "$JOURNAL"/logbook/*.md 2>/dev/null | sort | tail -1)
    if [ -n "$latest" ]; then
      echo
      echo "## Most recent logbook entry ($JOURNAL_NAME/logbook/$(basename "$latest"))"
      echo
      head_with_note "$latest" 150
    fi
  else
    echo
    echo "## Overview ($JOURNAL_NAME/overview.md)"
    echo
    head_with_note "$JOURNAL/overview.md" 120
  fi

  if grep -q '^## ' "$JOURNAL/preferences.md" 2>/dev/null; then
    echo
    echo "## What the person likes and rejects ($JOURNAL_NAME/preferences.md)"
    echo
    head_with_note "$JOURNAL/preferences.md" 80
  fi

  if grep -q '^### ' "$JOURNAL/$LESSONS" 2>/dev/null; then
    echo
    echo "## Lessons by topic ($JOURNAL_NAME/$LESSONS has the full text)"
    echo
    grep -E '^(## |### )' "$JOURNAL/$LESSONS" | head -80
  fi

  echo
  echo "## Everything in the journal ($JOURNAL_NAME/INDEX.md). Open entries only when needed."
  echo
  strip_frontmatter "$JOURNAL/INDEX.md" | grep -v '^# Index' | cat -s | sed '1{/^$/d;}' | head -150

  linked_context
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
  # "2026-10-16: Started the project" reads better as "16 Oct: Started the project".
  last="$(printf '%s' "$last" | sed -E 's/^\*?\*?([0-9]{4})-([0-9]{2})-([0-9]{2})\*?\*?:? */\3-\2 /; s/^0//' | awk '{
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
# projects folder. Saves asking about Downloads and the like.
looks_like_project() {
  local root="$1"
  [ -d "$root/.git" ] && return 0
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
  mkdir -p "$SCRIBE_HOME/notices"
  printf '%s\n' "$text" >"$SCRIBE_HOME/notices/$(__sanitize "$root")"
}

# The waiting messages for a project, or for every project from the home
# folder, joined into one line. Shown once, then deleted.
take_notices() {
  local root="$1" f out=""
  [ -d "$SCRIBE_HOME/notices" ] || return 0
  for f in "$SCRIBE_HOME"/notices/*; do
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
json_string() {
  if command -v jq >/dev/null 2>&1; then
    jq -Rs . 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
  else
    return 1
  fi
}

# The SessionStart hook. Claude gets the context. The person sees a one-line
# message if the curator updated a journal since their last session.
hook_session_start() {
  is_helper_session && return 0
  local input="" context message cwd root ctx_json msg_json
  [ -t 0 ] || input="$(cat || true)"
  context="$(printf '%s' "$input" | session_start_context)"
  cwd="$(json_field "$input" cwd)"
  root="$(project_root "${cwd:-${CLAUDE_PROJECT_DIR:-$PWD}}")"
  message="$(take_notices "$root")"
  if [ "$(json_field "$input" source)" = "startup" ] || [ -z "$(json_field "$input" source)" ]; then
    local recap
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
  if [ -n "$message" ] && ctx_json="$(printf '%s' "$context" | json_string)" && msg_json="$(printf '%s' "$message" | json_string)"; then
    printf '{"systemMessage":%s,"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$msg_json" "$ctx_json"
  else
    printf '%s\n' "$context"
  fi
}

# Prints context for Claude at the start of every session.
session_start_context() {
  local input="" cwd session name port
  [ -t 0 ] || input="$(cat || true)"
  cwd="$(json_field "$input" cwd)"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  session="$(json_field "$input" session_id)"
  [ -n "$session" ] || session="unknown"

  if has_legacy_install; then
    cat <<EOF
Terminal Scribe note: the old curl version of Terminal Scribe is still installed alongside the plugin, so both may write journals. In your next reply, tell the person this once and offer to run \`"$SCRIBE_BIN_PATH" remove-old-install\`, which removes the old hooks, commands and PATH line and keeps their archived projects.

EOF
  fi
  if [ ! -s "$REGISTRY" ] && [ -n "$(kit_ports)" ]; then
    cat <<EOF
Terminal Scribe note: the project list is empty, but the earlier project kit has $(kit_ports | grep -c .) projects in $(projects_dir). In your next reply, offer once to bring them in with \`"$SCRIBE_BIN_PATH" import-kit\`.

EOF
  fi

  sed -e "s|{{SCRIBE_BIN}}|$SCRIBE_BIN_PATH|g" -e "s|{{SESSION}}|$session|g" "$TEMPLATES/projects.md"
  echo

  set_project "$(project_root "$cwd")"

  if [ "$ROOT" = "$HOME_P" ] || [ "$ROOT" = "$(projects_dir)" ]; then
    echo "## Their projects, most recent first"
    echo
    cmd_list 2>/dev/null | head -60
    log "session-start: project list loaded in $ROOT"
    return 0
  fi

  if [ ! -d "$JOURNAL" ]; then
    if has_legacy_journal "$ROOT"; then
      cat <<EOF
Terminal Scribe: this project ($ROOT) has a journal in journal/ from the old version of Terminal Scribe. In your next reply, offer once to move it with \`"$SCRIBE_BIN_PATH" migrate\`. That moves it to .scribe/, removes the Terminal Scribe block from CLAUDE.md and the journal/ line from .gitignore, and keeps it out of git another way. Until then, keep following the journal instructions in CLAUDE.md.
EOF
      return 0
    fi
    is_declined "$ROOT" && return 0
    looks_like_project "$ROOT" || return 0
    cat <<EOF
Terminal Scribe is installed but this folder ($ROOT) is not one of their projects yet.

In your next reply, ask once whether to add it. Suggested wording: "Terminal Scribe can add this folder to your projects and keep a private journal of it, so I remember what we decided next time. Add it? (yes / no / not now)".

- Yes: run \`"$SCRIBE_BIN_PATH" adopt --session $session\` and tell them what it printed.
- No: run \`"$SCRIBE_BIN_PATH" init --decline\`, so you do not ask again.
- Not now, or no clear answer: do nothing. You will ask again next session.

Do not ask again this session once they have answered.
EOF
    return 0
  fi

  # A folder with a journal is a project: make sure it is on the list.
  if [ -z "$(reg_name_for_path "$ROOT")" ]; then
    name="$(slugify "$(basename "$ROOT")")"
    [ -z "$(reg_line "$name")" ] || name="$name-2"
    port="$(kit_ports | awk -F'\t' -v n="$(basename "$ROOT")" '$1 == n {print $2; exit}')"
    reg_add "$name" "$ROOT" "${port:-$(next_port)}"
  fi
  remember_session "$session" "$ROOT"

  if has_kit_hooks "$ROOT"; then
    cat <<EOF
Terminal Scribe note: this project still has the earlier project kit's own hooks, so its journal is being written twice. In your next reply, offer once to switch it over fully with \`"$SCRIBE_BIN_PATH" adopt --session $session\`. That removes the kit's two hooks from .claude/settings.json (keeping a backup) and stops its weekly job. The journal stays where it is.

EOF
  fi

  echo "# Current project: $(reg_name_for_path "$ROOT") ($ROOT)"
  echo
  project_context
  log "session-start: context loaded for $ROOT"
}

# Prepare one project for the curator. Prints the line the background job
# needs ("root|state|size|prompt|condensed|extra_read"), or nothing to skip.
prepare_curation() {
  local root="$1" transcript="$2" session="$3" size="$4" others="$5"
  local state_dir state last lock condensed note extra_read="" prompt_file
  set_project "$root"
  [ -d "$JOURNAL" ] || return 0
  [ -f "$JOURNAL/.paused" ] && { log "session-end: paused in $ROOT"; return 0; }

  state_dir="$JOURNAL/.state"
  mkdir -p "$state_dir"
  state="$state_dir/$(__sanitize "$session")"
  # Skip a transcript that has not grown since the curator last read it.
  last=$(cat "$state" 2>/dev/null || echo 0)
  [ "$size" -gt "${last:-0}" ] || { log "session-end: nothing new in $session for $ROOT"; return 0; }

  # One curator per project at a time. A lock older than 30 minutes is stale.
  lock="$state_dir/lock"
  if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin -30 2>/dev/null)" ]; then
    log "session-end: curator already running in $ROOT"
    return 0
  fi
  rm -rf "$lock"
  mkdir "$lock" 2>/dev/null || return 0

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
  printf '%s|%s|%s|%s|%s|%s\n' "$ROOT" "$state" "$size" "$prompt_file" "$condensed" "$extra_read"
}

# Starts the curator in the background for every project the session worked
# on. Each run may only read the session and the project, and only write
# inside the project's journal. It has no shell and no web access.
hook_session_end() {
  is_helper_session && return 0

  local input="" cwd transcript session size roots root jobs="" count others="no"
  [ -t 0 ] || input="$(cat || true)"
  cwd="$(json_field "$input" cwd)"
  [ -n "$cwd" ] || cwd="${CLAUDE_PROJECT_DIR:-$PWD}"
  transcript="$(json_field "$input" transcript_path)"
  session="$(json_field "$input" session_id)"
  [ -n "$session" ] || session="$(basename "${transcript:-unknown}" .jsonl)"

  # The projects this session touched: the folder it ran in, plus any it opened.
  roots="$(project_root "$cwd")"
  if [ -f "$SESSIONS/$(__sanitize "$session")" ]; then
    roots="$roots
$(cat "$SESSIONS/$(__sanitize "$session")")"
    rm -f "$SESSIONS/$(__sanitize "$session")"
  fi
  roots="$(printf '%s\n' "$roots" | awk 'NF && !seen[$0]++')"

  [ "$(config_get background on)" = "on" ] || { log "session-end: background curator is off"; return 0; }
  command -v claude >/dev/null 2>&1 || { log "session-end: claude not on PATH"; return 0; }
  { [ -n "$transcript" ] && [ -f "$transcript" ]; } || { log "session-end: no transcript"; return 0; }
  size=$(wc -c <"$transcript" | tr -d ' ')
  [ "$size" -ge 2000 ] || { log "session-end: transcript too short ($size bytes)"; return 0; }

  # Keep recall up to date with the conversation that just ended.
  ( recall_cache_one "$transcript" ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true

  count=$(printf '%s\n' "$roots" | grep -c .)
  [ "$count" -gt 1 ] && others="yes"
  [ "$(project_root "$cwd")" = "$HOME_P" ] && others="yes"

  while IFS= read -r root; do
    [ -n "$root" ] || continue
    [ "$root" = "$HOME_P" ] && continue
    jobs="$jobs$(prepare_curation "$root" "$transcript" "$session" "$size" "$others")
"
  done <<EOF
$roots
EOF
  jobs="$(printf '%s' "$jobs" | grep . || true)"
  [ -n "$jobs" ] || return 0

  # Run the curators one after another, detached, so Claude Code can exit.
  (
    printf '%s\n' "$jobs" | while IFS='|' read -r root state size prompt condensed extra_read; do
      set_project "$root"
      snapshot_journal
      marker="$JOURNAL/.state/started"
      : >"$marker"
      sleep 1
      if run_curator "$prompt" "$extra_read" >>"$JOURNAL/.state/helper.log" 2>&1; then
        echo "$size" >"$state"
        save_notice "$ROOT" "$(journal_changes "$JOURNAL" "$marker")"
      else
        save_notice "$ROOT" "" failed
      fi
      rm -f "$marker"
      build_index "$JOURNAL"
      rm -rf "$JOURNAL/.state/lock" "$prompt" ${condensed:+"$condensed"}
    done
  ) </dev/null >/dev/null 2>&1 &
  disown 2>/dev/null || true
  log "session-end: curator started for $session in $(printf '%s' "$jobs" | cut -d'|' -f1 | tr '\n' ' ')"
}

cmd_hook() {
  case "${1:-}" in
    session-start) hook_session_start ;;
    session-end)   hook_session_end ;;
    *) die "unknown hook '${1:-}'" ;;
  esac
  # A hook must never block or fail the user's session.
  return 0
}
