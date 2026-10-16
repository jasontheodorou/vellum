#!/bin/bash
# Sourced by bin/scribe. Written for bash 3.2+.
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
    jq -r -f "$TEMPLATES/condense.jq" "$transcript" >"$out" 2>/dev/null && [ -s "$out" ] && return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$transcript" >"$out" 2>/dev/null <<'PY' && [ -s "$out" ] && return 0
import json, sys

def clip(text, n):
    return text if len(text) <= n else text[:n] + " [...]"

for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    try:
        rec = json.loads(line)
    except ValueError:
        continue
    who = rec.get("type")
    if who not in ("user", "assistant") or rec.get("isMeta"):
        continue
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, str):
        content = [{"type": "text", "text": content}]
    for block in content or []:
        kind = block.get("type")
        if kind == "text" and block.get("text", "").strip():
            label = "PERSON: " if who == "user" else "CLAUDE: "
            print(label + clip(block["text"], 4000))
        elif kind == "tool_use":
            inp = block.get("input") or {}
            detail = ""
            for key in ("file_path", "command", "pattern", "description", "url"):
                if inp.get(key):
                    detail = str(inp[key])
                    break
            print("ACTION: " + block.get("name", "") + " " + clip(detail.replace("\n", " "), 200))
        elif kind == "tool_result" and block.get("is_error"):
            body = block.get("content")
            if isinstance(body, list):
                body = " ".join(b.get("text", "") for b in body if isinstance(b, dict))
            print("FAILED: " + clip(str(body or "").replace("\n", " "), 300))
PY
  fi
  rm -f "$out"
  return 1
}

# Write the curator's instructions to a file. $1 is the session note.
write_curator_prompt() {
  local note="$1" out="$2"
  # The note can span lines, which awk -v cannot take, so it goes in by environment.
  SCRIBE_NOTE="$note" awk -v project="$(basename "$ROOT")" -v j="$JOURNAL_NAME" -v lessons="$LESSONS" -v today="$(date '+%Y-%m-%d')" '
    { gsub(/\{\{PROJECT\}\}/, project); gsub(/\{\{J\}\}/, j); gsub(/\{\{LESSONS\}\}/, lessons); gsub(/\{\{TODAY\}\}/, today)
      if ($0 == "{{SESSION_NOTE}}") { print ENVIRON["SCRIBE_NOTE"]; next }
      print }' "$TEMPLATES/curator.md" >"$out"
}

# Run the curator in the project root. It may read the project and edit only
# inside the journal; it has no shell and no web access. $1 is the prompt file,
# $2 is an extra Read rule (or empty).
run_curator() {
  local prompt_file="$1" extra_read="${2:-}" allowed
  allowed="Edit(./$JOURNAL_NAME/**)"
  [ -n "$extra_read" ] && allowed="$allowed,$extra_read"
  set_model_args
  (cd "$ROOT" && SCRIBE_SUBAGENT=1 CLAUDE_JOURNAL_HOOK=1 claude -p \
    --tools "Read,Glob,Grep,Edit,Write" \
    --permission-mode dontAsk \
    --allowedTools "$allowed" \
    --no-session-persistence \
    ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} <"$prompt_file")
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_init() {
  set_project "$(project_root)"

  if [ "${1:-}" = "--decline" ]; then
    mkdir -p "$SCRIBE_HOME"
    touch "$DECLINED"
    grep -qxF "$ROOT" "$DECLINED" || echo "$ROOT" >>"$DECLINED"
    echo "Terminal Scribe will not ask about $ROOT again."
    return 0
  fi

  if [ "$ROOT" = "$HOME_P" ]; then
    die "your home folder cannot have a journal. Open Claude in a project folder instead."
  fi
  if has_legacy_journal "$ROOT"; then
    die "this project uses the old journal/ folder. Run 'scribe migrate' instead."
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
  rm -f "$ROOT/.scribe-declined"

  echo "Journaling is on for $ROOT."
  if [ "$JOURNAL_NAME" = ".scribe" ]; then
    echo "The journal is in $JOURNAL_NAME/ and is kept out of git."
  else
    echo "The journal is in $JOURNAL_NAME/."
  fi
  if [ "$(config_get background on)" = "on" ]; then
    echo "After each session a background helper fills in anything missed."
    echo "It runs Claude, so it uses some of your plan's allowance. 'scribe config background off' stops it."
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
      echo "This project has a journal from the old version. Run 'scribe migrate' to move it."
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
  echo "  background helper: $(config_get background on)"
}

cmd_off() {
  local yes=0
  [ "${1:-}" = "--yes" ] && yes=1
  require_journal

  if [ $yes -eq 0 ]; then
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
    summary=$(cd "$ROOT" && SCRIBE_SUBAGENT=1 CLAUDE_JOURNAL_HOOK=1 claude -p \
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

cmd_curate() {
  require_journal
  command -v claude >/dev/null 2>&1 || die "Claude Code is not on PATH, so the curator cannot run"
  local prompt_file
  prompt_file="$(mktemp)"
  write_curator_prompt "There is no new session to record, so skip step 2. Tidy the journal that is already there: turn decisions, experiments, lessons and preferences buried in the logbook into proper entries (step 3), then carry out step 4." "$prompt_file"
  echo "Curating the journal. This can take a minute or two."
  if ! run_curator "$prompt_file" ""; then
    rm -f "$prompt_file"
    die "the curator did not finish"
  fi
  rm -f "$prompt_file"
  build_index "$JOURNAL"
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
  [ -n "$name" ] || { echo "Usage: scribe link <project-name>" >&2; return 2; }
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
  imports="$JOURNAL/.imports"
  if [ ! -f "$imports" ] || ! grep -qxF "$entry" "$imports"; then
    echo "$entry" >>"$imports"
  fi
  echo "Linked ${entry#project:}. Its overview and lessons will load at the start of every session here."
}

cmd_unlink() {
  local name="${1:-}" safe imports
  [ -n "$name" ] || { echo "Usage: scribe unlink <project-name>" >&2; return 2; }
  safe="$(__sanitize "$name")"
  require_journal
  imports="$JOURNAL/.imports"
  if [ -f "$imports" ]; then
    grep -vxF -e "$safe" -e "project:$name" "$imports" >"$imports.tmp" || true
    mv "$imports.tmp" "$imports"
    [ -s "$imports" ] || rm -f "$imports"
  fi
  echo "Unlinked $safe."
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

# Move a project from the old journal/ layout to .scribe/.
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

  echo "Moved the journal from journal/ to $JOURNAL_NAME/ and removed the Terminal Scribe block from CLAUDE.md."
  echo "Check 'git status': CLAUDE.md and .gitignore may now show as changed."
}

# Undo what the old curl installer did to Claude Code and the shell.
# Archived projects in ~/.scribe/library are kept.
cmd_remove_old_install() {
  local settings="$HOME/.claude/settings.json" f rc
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
    cp "$settings" "$settings.scribe-backup"
    printf '%s\n' "$updated" >"$settings"
    echo "Removed the old hooks from $settings (backup saved as settings.json.scribe-backup)."
  fi

  for f in journal-pause.md journal-resume.md journal-status.md; do
    [ -f "$HOME/.claude/commands/$f" ] && grep -q 'scribe' "$HOME/.claude/commands/$f" && rm -f "$HOME/.claude/commands/$f"
  done

  for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile"; do
    [ -f "$rc" ] || continue
    if grep -q '\.scribe/bin' "$rc"; then
      grep -v '\.scribe/bin' "$rc" | grep -vx '# scribe' >"$rc.tmp" && mv "$rc.tmp" "$rc"
      echo "Removed the old PATH line from $rc."
    fi
  done

  rm -rf "${SCRIBE_HOME:?}/bin" "${SCRIBE_HOME:?}/hooks" "${SCRIBE_HOME:?}/templates" \
         "${SCRIBE_HOME:?}/uninstall.sh" "${SCRIBE_HOME:?}/VERSION"
  echo "The old install is gone. Archived projects in $LIBRARY were kept."
}

cmd_doctor() {
  local issues=0
  echo "Terminal Scribe $(plugin_version)"
  if command -v claude >/dev/null 2>&1; then
    echo "  ok   Claude Code is installed"
  else
    echo "  FAIL Claude Code is not on PATH, so archive summaries and the background helper cannot run"
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
    echo "  FAIL the old curl install is still wired in. Run 'scribe remove-old-install'"
    issues=$((issues + 1))
  else
    echo "  ok   no old install left over"
  fi
  echo "  ok   background helper: $(config_get background on), model: $(config_get model default)"
  echo
  if [ $issues -eq 0 ]; then
    echo "Everything looks healthy."
  else
    echo "$issues problem(s) found."
    return 1
  fi
}
