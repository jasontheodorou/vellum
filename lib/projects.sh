#!/bin/bash
# Sourced by bin/scribe. Written for bash 3.2+.
# shellcheck shell=bash

# Projects: the list of projects, and starting, opening, renaming, closing,
# searching and checking them.
#
# The list lives in ~/.scribe/projects.tsv, one project per line:
#   name <TAB> folder <TAB> port <TAB> status <TAB> created <TAB> closed
# status is "active" or "closed".

TAB="$(printf '\t')"

# ---------------------------------------------------------------------------
# The project list
# ---------------------------------------------------------------------------

projects_dir() {
  local dir
  dir="$(config_get projects-dir "$HOME/projects")"
  (cd "$dir" 2>/dev/null && pwd -P) || echo "$dir"
}

reg_ensure() {
  mkdir -p "$SCRIBE_HOME"
  [ -f "$REGISTRY" ] || : >"$REGISTRY"
}

# Print the line for a project name, or nothing.
reg_line() {
  [ -f "$REGISTRY" ] || return 0
  awk -F'\t' -v n="$1" '$1 == n {print; exit}' "$REGISTRY"
}

# Print the name registered for a folder, or nothing.
reg_name_for_path() {
  local p
  [ -f "$REGISTRY" ] || return 0
  p="$( (cd "$1" 2>/dev/null && pwd -P) || echo "$1")"
  awk -F'\t' -v p="$p" '$2 == p {print $1; exit}' "$REGISTRY"
}

field() {
  printf '%s\n' "$1" | cut -d "$TAB" -f "$2"
}

reg_add() {
  reg_ensure
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "${4:-active}" "${5:-$(date '+%Y-%m-%d')}" "${6:-}" >>"$REGISTRY"
}

# Set field number $2 of project $1 to $3.
reg_set() {
  awk -F'\t' -v OFS='\t' -v n="$1" -v f="$2" -v v="$3" '$1 == n {$f = v} {print}' "$REGISTRY" >"$REGISTRY.tmp"
  mv "$REGISTRY.tmp" "$REGISTRY"
}

# Ports already promised to a project, here or in the earlier project kit.
known_ports() {
  [ -f "$REGISTRY" ] && cut -d "$TAB" -f3 "$REGISTRY"
  kit_ports | cut -d "$TAB" -f2
}

port_in_use() {
  command -v lsof >/dev/null 2>&1 || return 1
  lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1
}

next_port() {
  local port
  port=$(known_ports | grep -E '^[0-9]+$' | sort -n | tail -1)
  [ -n "$port" ] || port=3000
  port=$((port + 1))
  while port_in_use "$port"; do port=$((port + 1)); done
  echo "$port"
}

# "Garden Planner!" becomes "garden-planner".
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Turn what the person called a project into its registered name. Accepts the
# exact name, any capitalisation, or a unique part of a name.
resolve_project() {
  local query="$1" lower matches count
  [ -n "$query" ] || die "say which project"
  [ -f "$REGISTRY" ] || die "there are no projects yet. Say 'start a new project called ...' or 'import my projects'."
  lower=$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')
  matches=$(awk -F'\t' -v q="$lower" 'tolower($1) == q {print $1}' "$REGISTRY")
  if [ -z "$matches" ]; then
    matches=$(awk -F'\t' -v q="$lower" 'index(tolower($1), q) {print $1}' "$REGISTRY")
  fi
  count=$(printf '%s' "$matches" | grep -c . || true)
  if [ "$count" -eq 1 ]; then
    echo "$matches"
    return 0
  fi
  if [ "$count" -gt 1 ]; then
    echo "scribe: '$query' matches more than one project:" >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2
    exit 1
  fi
  if [ -d "$(projects_dir)/$query" ]; then
    die "'$query' is a folder in $(projects_dir) but not on the project list. Say 'add $query to my projects'."
  fi
  die "there is no project called '$query'. Say 'list my projects' to see them."
}

# Record that this Claude session worked on a project, so the curator
# organises that project's journal when the session ends.
remember_session() {
  local session="$1" path="$2"
  [ -n "$session" ] || return 0
  session=$(__sanitize "$session")
  mkdir -p "$SESSIONS"
  if [ ! -f "$SESSIONS/$session" ] || ! grep -qxF "$path" "$SESSIONS/$session"; then
    echo "$path" >>"$SESSIONS/$session"
  fi
}

# Pull --session ID out of the arguments. Sets SESSION_ID and ARGS.
parse_session() {
  SESSION_ID=""
  ARGS=()
  while [ $# -gt 0 ]; do
    case "$1" in
      --session) SESSION_ID="${2:-}"; shift 2 || shift ;;
      --session=*) SESSION_ID="${1#--session=}"; shift ;;
      *) ARGS+=("$1"); shift ;;
    esac
  done
}

# The newest logbook day of a project, or nothing.
last_worked() {
  local journal="$1" latest
  latest=$(ls -1 "$journal"/logbook/*.md 2>/dev/null | sed 's|.*/||; s|\.md$||' | sort | tail -1)
  echo "$latest"
}

# One sentence about a project, from its overview.
project_summary() {
  local overview="$1/overview.md"
  [ -f "$overview" ] || return 0
  awk '
    /^\*\*One-sentence description:\*\*/ { sub(/^\*\*One-sentence description:\*\*[[:space:]]*/, ""); print; exit }
    /^## What this is/ { want = 1; next }
    want && /^## / { exit }
    want && NF && !/^Not written yet/ { print; exit }
  ' "$overview" | cut -c1-110
}

# ---------------------------------------------------------------------------
# The earlier project kit
# ---------------------------------------------------------------------------

# Print "name<TAB>port" for every project in the kit's ~/projects/.ports.json.
kit_ports() {
  local file
  file="$(projects_dir)/.ports.json"
  [ -f "$file" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.projects // {} | to_entries[] | "\(.key)\t\(.value)"' "$file" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys
for k, v in json.load(open(sys.argv[1])).get("projects", {}).items(): print(f"{k}\t{v}")' "$file" 2>/dev/null
  fi
}

# The kit put a SessionStart and a Stop hook in each project's own settings.
has_kit_hooks() {
  local settings="$1/.claude/settings.json"
  [ -f "$settings" ] && grep -qE 'journal-hook\.sh|\.claude/hooks/session-start\.sh' "$settings"
}

kit_weekly_job() {
  echo "$HOME/Library/LaunchAgents/com.jasont.design-journal-weekly-$1.plist"
}

# Take the kit's hooks out of a project's .claude/settings.json and stop its
# weekly job, because Scribe now does both. Keeps backups.
retire_kit() {
  local root="$1" name="$2" settings updated plist
  settings="$root/.claude/settings.json"
  if has_kit_hooks "$root"; then
    updated=""
    if command -v jq >/dev/null 2>&1; then
      updated=$(jq '
        if .hooks then
          .hooks |= with_entries(.value |= map(select(
            (.hooks // []) | map(.command // "") | any(test("journal-hook\\.sh|\\.claude/hooks/session-start\\.sh")) | not
          )))
          | .hooks |= with_entries(select(.value | length > 0))
          | if (.hooks | length) == 0 then del(.hooks) else . end
        else . end' "$settings") || updated=""
    elif command -v python3 >/dev/null 2>&1; then
      updated=$(python3 - "$settings" <<'PY'
import json, re, sys
data = json.load(open(sys.argv[1]))
hooks = data.get("hooks", {})
pattern = re.compile(r"journal-hook\.sh|\.claude/hooks/session-start\.sh")
for event in list(hooks):
    kept = [g for g in hooks[event]
            if not any(pattern.search(h.get("command", "")) for h in g.get("hooks", []))]
    if kept:
        hooks[event] = kept
    else:
        del hooks[event]
if not hooks:
    data.pop("hooks", None)
print(json.dumps(data, indent=2))
PY
) || updated=""
    fi
    if [ -n "$updated" ]; then
      cp "$settings" "$settings.kit-backup"
      printf '%s\n' "$updated" >"$settings"
      echo "Took the project kit's hooks out of .claude/settings.json (backup: settings.json.kit-backup)."
    else
      echo "Could not edit $settings (needs jq or python3). Remove the kit's two hooks by hand."
    fi
  fi
  plist="$(kit_weekly_job "$name")"
  if [ -f "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    mkdir -p "$SCRIBE_HOME/retired"
    mv "$plist" "$SCRIBE_HOME/retired/"
    echo "Stopped the project kit's weekly job (moved to ~/.scribe/retired/). The curator writes weekly round-ups now."
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_new() {
  parse_session "$@"
  local name about="" dir port
  name="${ARGS[0]:-}"
  [ -n "$name" ] || die "say what the project is called"
  [ "${ARGS[1]:-}" = "--about" ] && about="${ARGS[2]:-}"
  name="$(slugify "$name")"
  [ -n "$name" ] || die "that name has no letters or numbers in it"
  [ -z "$(reg_line "$name")" ] || die "there is already a project called $name. Say 'open $name'."
  dir="$(projects_dir)/$name"
  [ -e "$dir" ] && die "$dir already exists. Say 'add $name to my projects' to use it."

  mkdir -p "$dir"
  dir="$(cd "$dir" && pwd -P)"
  (cd "$dir" && git init -q 2>/dev/null) || true
  {
    echo "# $name"
    [ -n "$about" ] && printf '\n%s\n' "$about"
  } >"$dir/README.md"
  printf '.DS_Store\nnode_modules/\ndist/\n.env\n.env.*\n!.env.example\n' >"$dir/.gitignore"

  set_project "$dir"
  seed_journal "$JOURNAL"
  if [ -n "$about" ]; then
    awk -v about="$about" '/^Not written yet/ {print about; next} {print}' "$JOURNAL/overview.md" >"$JOURNAL/overview.tmp"
    mv "$JOURNAL/overview.tmp" "$JOURNAL/overview.md"
  fi
  build_index "$JOURNAL"
  add_git_exclude "$dir"

  port="$(next_port)"
  reg_add "$name" "$dir" "$port"
  remember_session "$SESSION_ID" "$dir"

  echo "Started $name."
  echo "  folder: $dir"
  echo "  port:   $port (for a local web server, if it needs one)"
  echo "  It has git, a README and a journal. The journal is kept out of git."
  echo
  echo "From now on, run every command for this project inside $dir (cd there first)."
  echo
  project_context
}

cmd_open() {
  parse_session "$@"
  local name line dir
  name="$(resolve_project "${ARGS[*]:-}")"
  line="$(reg_line "$name")"
  dir="$(field "$line" 2)"
  [ -d "$dir" ] || die "$name's folder, $dir, is missing. It may have been moved or deleted."
  remember_session "$SESSION_ID" "$dir"

  echo "Project: $name"
  echo "  folder: $dir"
  echo "  port:   $(field "$line" 3)"
  [ "$(field "$line" 4)" = "closed" ] && echo "  This project is closed (since $(field "$line" 6)). Say 'reopen $name' to make it active again."
  echo
  echo "Run every command for this project inside $dir (cd there first)."
  echo
  set_project "$dir"
  if [ ! -d "$JOURNAL" ]; then
    echo "It has no journal yet. Ask the person whether to start one; if yes, run scribe init inside $dir."
    return 0
  fi
  project_context
}

cmd_list() {
  local all=0 line name dir port status closed last summary when hidden=0
  [ "${1:-}" = "--all" ] && all=1
  if [ ! -s "$REGISTRY" ]; then
    echo "There are no projects on the list yet."
    [ -n "$(kit_ports)" ] && echo "Your project kit has $(kit_ports | grep -c .) projects. Say 'import my projects' to bring them in."
    return 0
  fi
  # Newest work first.
  while IFS= read -r line; do
    name="$(field "$line" 1)"; dir="$(field "$line" 2)"; port="$(field "$line" 3)"
    status="$(field "$line" 4)"; closed="$(field "$line" 6)"
    if [ "$status" = "closed" ] && [ $all -eq 0 ]; then
      continue
    fi
    set_project "$dir"
    last="$(last_worked "$JOURNAL")"
    summary="$(project_summary "$JOURNAL")"
    when="no sessions yet"
    [ -n "$last" ] && when="last worked on $last"
    printf '%s\t%s\n' "${last:-0000-00-00}" "$name  (port $port, $when${closed:+, closed $closed})${summary:+$TAB$summary}"
  done <"$REGISTRY" | sort -r | cut -f2- | while IFS="$TAB" read -r head summary; do
    echo "$head"
    [ -n "$summary" ] && echo "    $summary"
  done
  if [ $all -eq 0 ]; then
    hidden=$(awk -F'\t' '$4 == "closed"' "$REGISTRY" | grep -c . || true)
    [ "$hidden" -gt 0 ] && echo "($hidden closed project(s) not shown. Say 'list all my projects' to see them.)"
  fi
  return 0
}

cmd_rename() {
  local name new line dir target here
  name="$(resolve_project "${1:-}")"
  new="$(slugify "${2:-}")"
  [ -n "$new" ] || die "say the new name"
  [ -z "$(reg_line "$new")" ] || die "there is already a project called $new"
  line="$(reg_line "$name")"
  dir="$(field "$line" 2)"
  target="$(dirname "$dir")/$new"
  [ -e "$target" ] && die "$target already exists"
  here="$(pwd)"

  mv "$dir" "$target"
  reg_set "$name" 2 "$target"
  reg_set "$name" 1 "$new"

  set_project "$target"
  if [ -d "$JOURNAL/logbook" ]; then
    printf '\n## Renamed from %s to %s\n\nThe project folder moved from `%s` to `%s`.\n' "$name" "$new" "$dir" "$target" >>"$JOURNAL/logbook/$(date '+%Y-%m-%d').md"
  fi
  echo "Renamed $name to $new."
  echo "  folder: $target"
  case "$here/" in "$dir"/*) echo "  The shell was inside the old folder. cd $target before running anything else." ;; esac
  [ -f "$(kit_weekly_job "$name")" ] && echo "  The project kit's weekly job still uses the old name. Say 'adopt $new' to retire it."
  if (cd "$target" && git remote get-url origin >/dev/null 2>&1); then
    echo "  The GitHub repository still has its old name. Rename it on GitHub if you want them to match."
  fi
  return 0
}

cmd_close() {
  local name line dir archive=1
  [ "${2:-}" = "--no-archive" ] && archive=0
  name="$(resolve_project "${1:-}")"
  line="$(reg_line "$name")"
  dir="$(field "$line" 2)"
  [ "$(field "$line" 4)" = "closed" ] && die "$name is already closed"

  set_project "$dir"
  if [ $archive -eq 1 ] && [ -d "$JOURNAL" ]; then
    (cd "$dir" && cmd_archive) || echo "The archive could not be made, so the project was closed without one."
  fi
  reg_set "$name" 4 closed
  reg_set "$name" 6 "$(date '+%Y-%m-%d')"
  echo "Closed $name. Its folder and journal are kept. Say 'reopen $name' to bring it back."
  if port_in_use "$(field "$line" 3)"; then
    echo "It is still running on port $(field "$line" 3). Say 'stop $name' to stop it."
  fi
  return 0
}

cmd_reopen() {
  local name
  name="$(resolve_project "${1:-}")"
  reg_set "$name" 4 active
  reg_set "$name" 6 ""
  echo "Reopened $name."
}

# Add an existing folder to the project list, start its journal if it has
# none, and retire the project kit's own hooks if it has them.
cmd_adopt() {
  parse_session "$@"
  local dir name port existing
  dir="${ARGS[0]:-}"
  if [ -n "$dir" ] && [ ! -d "$dir" ]; then
    # A name in the projects folder.
    [ -d "$(projects_dir)/$dir" ] && dir="$(projects_dir)/$dir"
  fi
  dir="$(project_root "${dir:-$PWD}")"
  [ -d "$dir" ] || die "there is no folder at $dir"
  [ "$dir" = "$HOME_P" ] && die "your home folder cannot be a project"

  existing="$(reg_name_for_path "$dir")"
  if [ -n "$existing" ]; then
    name="$existing"
    echo "$name is already on the project list."
  else
    name="$(slugify "$(basename "$dir")")"
    [ -z "$(reg_line "$name")" ] || name="$name-2"
    port="$(kit_ports | awk -F'\t' -v n="$(basename "$dir")" '$1 == n {print $2; exit}')"
    [ -n "$port" ] || port="$(next_port)"
    reg_add "$name" "$dir" "$port"
    echo "Added $name to the project list (port $port)."
  fi

  set_project "$dir"
  if [ ! -d "$JOURNAL" ]; then
    seed_journal "$JOURNAL"
    add_git_exclude "$dir"
    echo "Started a journal in $JOURNAL_NAME/."
  else
    seed_journal "$JOURNAL"
    echo "Using its existing journal in $JOURNAL_NAME/."
  fi
  build_index "$JOURNAL"
  retire_kit "$dir" "$(basename "$dir")"
  remember_session "$SESSION_ID" "$dir"
  return 0
}

# Put every project from the earlier project kit on the list. Changes nothing
# inside the projects; each one's kit hooks are retired when it is next opened.
cmd_import_kit() {
  local added=0 name port dir
  while IFS="$TAB" read -r name port; do
    [ -n "$name" ] || continue
    dir="$(projects_dir)/$name"
    [ -d "$dir" ] || continue
    [ -n "$(reg_name_for_path "$dir")" ] && continue
    [ -z "$(reg_line "$name")" ] || continue
    reg_add "$name" "$dir" "$port"
    added=$((added + 1))
  done <<EOF
$(kit_ports)
EOF
  echo "Added $added project(s) from the project kit."
  cmd_list
}

cmd_running() {
  local line name port pids found=0
  command -v lsof >/dev/null 2>&1 || die "lsof is not available, so running servers cannot be checked"
  [ -f "$REGISTRY" ] || { echo "There are no projects on the list yet."; return 0; }
  while IFS= read -r line; do
    name="$(field "$line" 1)"; port="$(field "$line" 3)"
    [ -n "$port" ] || continue
    pids="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ')"
    if [ -n "$pids" ]; then
      echo "$name is running at http://localhost:$port (process $pids)"
      found=1
    fi
  done <"$REGISTRY"
  [ $found -eq 1 ] || echo "None of your projects is running."
  return 0
}

cmd_stop() {
  local name port pids
  name="$(resolve_project "${1:-}")"
  port="$(field "$(reg_line "$name")" 3)"
  pids="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null || true)"
  [ -n "$pids" ] || { echo "$name is not running."; return 0; }
  # shellcheck disable=SC2086  # one or more process ids
  kill $pids
  echo "Stopped $name (port $port)."
}

# Search every project's journal and the archive library.
cmd_search() {
  local query="$*" line name dir hits total=0
  [ -n "$query" ] || die "say what to search for"
  if [ -f "$REGISTRY" ]; then
    while IFS= read -r line; do
      name="$(field "$line" 1)"; dir="$(field "$line" 2)"
      set_project "$dir"
      [ -d "$JOURNAL" ] || continue
      hits="$(grep -rinIF --include='*.md' -- "$query" "$JOURNAL" 2>/dev/null | grep -v '/INDEX\.md:' | head -8)"
      [ -n "$hits" ] || continue
      echo "## $name"
      printf '%s\n' "$hits" | sed "s|^$JOURNAL/|$JOURNAL_NAME/|" | cut -c1-220
      echo
      total=$((total + 1))
    done <"$REGISTRY"
  fi
  if [ -d "$LIBRARY" ]; then
    hits="$(grep -rinIF -- "$query" "$LIBRARY" 2>/dev/null | head -8)"
    if [ -n "$hits" ]; then
      echo "## Archived projects"
      printf '%s\n' "$hits" | sed "s|^$LIBRARY/|library/|" | cut -c1-220
      total=$((total + 1))
    fi
  fi
  [ $total -gt 0 ] || echo "Nothing in any journal mentions \"$query\"."
  return 0
}

# What happened across every active project in the last N days.
cmd_digest() {
  local days="${1:-7}" since line name dir f found=0 any
  since="$(date -v-"${days}"d '+%Y-%m-%d' 2>/dev/null || date -d "-$days days" '+%Y-%m-%d')"
  [ -f "$REGISTRY" ] || { echo "There are no projects on the list yet."; return 0; }
  echo "Work since $since:"
  while IFS= read -r line; do
    [ "$(field "$line" 4)" = "active" ] || continue
    name="$(field "$line" 1)"; dir="$(field "$line" 2)"
    set_project "$dir"
    any=0
    for f in "$JOURNAL"/logbook/*.md; do
      [ -f "$f" ] || continue
      [ "$(basename "$f" .md)" \< "$since" ] && continue
      [ $any -eq 0 ] && { echo; echo "## $name"; any=1; }
      echo "- $(basename "$f" .md):"
      grep -E '^## ' "$f" | sed 's/^## /    /' | head -8
    done
    for f in "$JOURNAL"/decisions/*.md; do
      [ -f "$f" ] || continue
      [ "$(entry_fields "$f" | cut -d $'\037' -f1)" \< "$since" ] && continue
      [ $any -eq 0 ] && { echo; echo "## $name"; any=1; }
      echo "- decision: $(entry_fields "$f" | cut -d $'\037' -f3)"
    done
    [ $any -eq 1 ] && found=1
  done <"$REGISTRY"
  [ $found -eq 1 ] || echo "No journal entries in that time."
  return 0
}

# Checks before code is pushed anywhere. Exits 1 if anything needs attention.
cmd_preship() {
  local root issues=0 hits remote patterns
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "this folder is not a git repository"
  cd "$root" || exit 1
  set_project "$root"
  warn() { echo "  check  $1"; issues=$((issues + 1)); }
  ok() { echo "  ok     $1"; }

  echo "Before you push $(basename "$root"):"
  [ -f README.md ] && ok "README.md is there" || warn "there is no README.md"
  if [ -f LICENSE ] || [ -f LICENSE.md ] || [ -f LICENSE.txt ]; then ok "there is a licence"; else warn "there is no LICENSE file, so others may not reuse the code"; fi

  patterns='(AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|api[_-]?key[[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9_-]{16,}|BEGIN (RSA|OPENSSH|DSA|EC) PRIVATE KEY|Bearer [A-Za-z0-9_.-]{20,}|sk-[A-Za-z0-9_-]{32,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[bp]-[A-Za-z0-9-]{20,})'
  hits="$(git ls-files -z | xargs -0 grep -lE "$patterns" 2>/dev/null | grep -v '\.example$' || true)"
  if [ -n "$hits" ]; then warn "these files may contain passwords or keys:"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "no passwords or keys found in tracked files"; fi

  hits="$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.example$' || true)"
  if [ -n "$hits" ]; then warn ".env files are tracked by git:"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "no .env files are tracked"; fi

  hits="$(git ls-files | grep -E '^(client-data|private)/' | head -5 || true)"
  if [ -n "$hits" ]; then warn "files in client-data/ or private/ are tracked"; else ok "nothing in client-data/ or private/ is tracked"; fi

  if [ "$JOURNAL_NAME" = ".scribe" ] && [ -n "$(git ls-files .scribe | head -1)" ]; then
    warn "the private journal in .scribe/ is tracked by git"
  else
    ok "the private journal is not tracked"
  fi

  hits="$(git ls-files -z | xargs -0 du -k 2>/dev/null | awk '$1 > 5120 {print $2}' | head -5 || true)"
  if [ -n "$hits" ]; then warn "these files are over 5 MB:"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "no files over 5 MB"; fi

  remote="$(git remote get-url origin 2>/dev/null || true)"
  if [ -z "$remote" ]; then
    echo "  note   there is no GitHub repository yet"
  elif command -v gh >/dev/null 2>&1; then
    echo "  note   pushes go to $remote ($(gh repo view "$remote" --json visibility -q .visibility 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "visibility unknown"))"
  else
    echo "  note   pushes go to $remote"
  fi

  echo
  if [ $issues -eq 0 ]; then
    echo "Nothing to fix."
  else
    echo "$issues thing(s) to look at before pushing."
    return 1
  fi
}

# Create a GitHub repository for the current project and push it.
cmd_publish() {
  local root name visibility="--private"
  [ "${1:-}" = "--public" ] && visibility="--public"
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "this folder is not a git repository"
  command -v gh >/dev/null 2>&1 || die "the GitHub command line tool (gh) is not installed. Install it with 'brew install gh'."
  gh auth status >/dev/null 2>&1 || die "you are not signed in to GitHub. Run 'gh auth login' in Terminal first."
  cd "$root" || exit 1
  git remote get-url origin >/dev/null 2>&1 && die "this project already has a remote: $(git remote get-url origin)"
  git rev-parse HEAD >/dev/null 2>&1 || die "there are no commits yet, so there is nothing to push"
  cmd_preship || die "fix the checks above first"
  name="$(basename "$root")"
  gh repo create "$name" "$visibility" --source=. --remote=origin --push
  echo "Published $name to GitHub (${visibility#--})."
}

# ---------------------------------------------------------------------------
# Status line
# ---------------------------------------------------------------------------

# The registered project that contains a folder: the longest matching path.
reg_name_containing() {
  local d
  [ -f "$REGISTRY" ] || return 0
  d="$( (cd "$1" 2>/dev/null && pwd -P) || echo "$1")"
  awk -F'\t' -v d="$d/" 'index(d, $2 "/") == 1 && length($2) > best {best = length($2); name = $1} END {if (name != "") print name}' "$REGISTRY"
}

# Each project gets its own colour, the same every time.
project_colour() {
  local colours="37 170 208 71 68 178 133 30" n
  n=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
  set -- $colours
  shift $(( n % $# ))
  echo "$1"
}

# Is something serving this port? Cached for 15 seconds, because the status
# line redraws often and lsof is slow.
port_running_cached() {
  local port="$1" cache="$SCRIBE_HOME/.cache/port-$1" now
  now=$(date +%s)
  mkdir -p "$SCRIBE_HOME/.cache" 2>/dev/null || return 1
  if [ -f "$cache" ] && [ $((now - $(stat -f %m "$cache" 2>/dev/null || stat -c %Y "$cache" 2>/dev/null || echo 0))) -lt 15 ]; then
    [ "$(cat "$cache")" = "1" ]
    return
  fi
  if port_in_use "$port"; then echo 1 >"$cache"; return 0; fi
  echo 0 >"$cache"
  return 1
}

# Claude Code's status line. Reads the session's JSON on stdin and prints one
# quiet line: the project's name in its own colour. Anything else appears only
# when it needs attention: the server is running, the branch is not the main
# one, commits are waiting to be pushed, or the journal is paused.
cmd_statusline() {
  local input="" cwd session name line dir port root colour out branch ahead
  [ -t 0 ] || input="$(cat || true)"
  cwd="$(json_field "$input" cwd)"
  [ -n "$cwd" ] || cwd="$PWD"

  name="$(reg_name_containing "$cwd")"
  # Claude sometimes looks in other folders. Stay on the last project this
  # session worked in, so the name does not flicker away.
  session="$(json_field "$input" session_id)"
  if [ -z "$name" ] && [ -n "$session" ] && [ -f "$SESSIONS/$(__sanitize "$session")" ]; then
    name="$(reg_name_containing "$(tail -1 "$SESSIONS/$(__sanitize "$session")")")"
  fi
  if [ -n "$name" ]; then
    line="$(reg_line "$name")"
    dir="$(field "$line" 2)"
    port="$(field "$line" 3)"
  else
    # Not on the list: a project kit folder, or any folder with a journal.
    root="$(project_root "$cwd")"
    set_project "$root"
    [ "$root" != "$HOME_P" ] || return 0
    case "$root/" in "$(projects_dir)"/*) ;; *) [ -d "$JOURNAL" ] || return 0 ;; esac
    dir="$root"
    name="$(basename "$root")"
    port="$(kit_ports | awk -F'\t' -v n="$name" '$1 == n {print $2; exit}')"
  fi
  set_project "$dir"
  [ -n "$session" ] && [ "$(tail -1 "$SESSIONS/$(__sanitize "$session")" 2>/dev/null)" != "$dir" ] && remember_session "$session" "$dir"

  colour="$(project_colour "$name")"
  out="$(printf '\033[38;5;%sm●\033[0m \033[1;38;5;%sm%s\033[0m' "$colour" "$colour" "$name")"

  if [ -n "$port" ] && port_running_cached "$port"; then
    out="$out  $(printf '\033[38;5;71mlive on :%s\033[0m' "$port")"
  fi

  if [ -e "$dir/.git" ]; then
    branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
    case "$branch" in
      ""|main|master) ;;
      *) out="$out  $(printf '\033[2m%s\033[0m' "$branch")" ;;
    esac
    ahead="$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || true)"
    [ -n "$ahead" ] && [ "$ahead" -gt 0 ] && out="$out  $(printf '\033[38;5;208m%s to push\033[0m' "$ahead")"
  fi

  [ -f "$JOURNAL/.paused" ] && out="$out  $(printf '\033[38;5;178mjournal paused\033[0m')"

  printf '%s' "$out"
}
