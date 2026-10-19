#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# Projects: the list of projects, and starting, opening, renaming, closing,
# searching and checking them.
#
# The list lives in ~/.vellum/projects.tsv, one project per line:
#   name <TAB> folder <TAB> port <TAB> status <TAB> created <TAB> closed <TAB> shape
# status is "active" or "closed". shape is the project's mark on the status line.
#
# Several Claude windows can run Vellum at once, so every change to the list
# goes through reg_update, which takes a lock and writes a fresh file before
# swapping it in. The status line and the list command only read it.

TAB="$(printf '\t')"

# What to say when a name has nothing a folder name can use.
SLUG_HINT="use at least one plain letter or number (a–z, 0–9)"

# Shapes for the status line. All are one column wide in Mac terminal fonts.
SHAPES="● ◆ ▲ ■ ★ ▼ ◉ ✚ ♣ ♠"

# ---------------------------------------------------------------------------
# The project list
# ---------------------------------------------------------------------------

projects_dir() {
  local dir
  dir="$(config_get projects-dir "$HOME/projects")"
  (cd "$dir" 2>/dev/null && pwd -P) || echo "$dir"
}

reg_ensure() {
  mkdir -p "$VELLUM_HOME"
  [ -f "$REGISTRY" ] || : >"$REGISTRY"
}

# The list without blank lines or Windows line endings, for reading.
reg_lines() {
  [ -f "$REGISTRY" ] || return 0
  tr -d '\r' <"$REGISTRY" | LC_ALL=C awk 'NF'
}

# Print the line for a project name, or nothing.
reg_line() {
  [ -f "$REGISTRY" ] || return 0
  REG_N="$1" LC_ALL=C awk -F'\t' '{sub(/\r$/, "")} $1 == ENVIRON["REG_N"] {print; exit}' "$REGISTRY"
}

# Print the name registered for a folder, or nothing.
reg_name_for_path() {
  local p
  [ -f "$REGISTRY" ] || return 0
  p="$( (cd "$1" 2>/dev/null && pwd -P) || echo "$1")"
  REG_P="$p" LC_ALL=C awk -F'\t' '{sub(/\r$/, "")} $2 == ENVIRON["REG_P"] {print $1; exit}' "$REGISTRY"
}

# Print the registered name that is the same as a slug once both are written
# the same way, so "Portfolio" (from the project kit) matches "portfolio".
reg_name_matching() {
  reg_lines | REG_Q="$1" LC_ALL=C awk -F'\t' '
    {s = tolower($1); gsub(/[^a-z0-9._-]+/, "-", s); if (s == ENVIRON["REG_Q"]) {print $1; exit}}'
}

field() {
  printf '%s\n' "$1" | cut -d "$TAB" -f "$2"
}

# Only one process changes the list at a time. The lock is a folder, because
# making a folder either works or fails in one step. A lock older than 30
# seconds was left by a process that was stopped part way, so it is cleared.
reg_lock() {
  local lock="$REGISTRY.lock" tries=0 age
  mkdir -p "$VELLUM_HOME" 2>/dev/null || return 1
  until mkdir "$lock" 2>/dev/null; do
    age=$(( $(date +%s) - $(stat -f %m "$lock" 2>/dev/null || date +%s) ))
    if [ "$age" -gt 30 ]; then
      rmdir "$lock" 2>/dev/null
      continue
    fi
    tries=$((tries + 1))
    [ "$tries" -lt 300 ] || return 1
    sleep 0.05
  done
}

reg_unlock() {
  rmdir "$REGISTRY.lock" 2>/dev/null || true
}

# Give each project without a shape the one fewest projects use, in list order,
# and add the line in $1 (if any) the same way. Reads the list on input and
# prints the whole list. Changes nothing on disk.
reg_fill_shapes() {
  REG_NEW="${1:-}" VELLUM_SHAPES="$SHAPES" LC_ALL=C awk -F'\t' -v OFS='\t' '
    function pick(   i, best) {
      best = ""
      for (i = 1; i <= ns; i++) if (best == "" || cnt[sh[i]] < cnt[best]) best = sh[i]
      cnt[best]++
      return best
    }
    BEGIN { ns = split(ENVIRON["VELLUM_SHAPES"], sh, " ") }
    { sub(/\r$/, "") }
    /^[[:space:]]*$/ { next }
    { line[++n] = $0; if ($7 != "") cnt[$7]++ }
    END {
      for (i = 1; i <= n; i++) {
        $0 = line[i]
        if ($7 == "") $7 = pick()
        print
      }
      if (ENVIRON["REG_NEW"] != "") {
        $0 = ENVIRON["REG_NEW"]
        if ($7 == "") $7 = pick()
        print
      }
    }'
}

# Change the list: run a command with the list on its input, and put what it
# prints in place of the list. Every change goes through here. Each process
# writes its own temporary file next to the list, under the lock.
reg_update() {
  local tmp
  reg_ensure
  reg_lock || { echo "vellum: the project list is busy. Try again in a moment." >&2; return 1; }
  tmp="$(mktemp "$REGISTRY.XXXXXX" 2>/dev/null)" || {
    reg_unlock
    echo "vellum: could not write to $VELLUM_HOME" >&2
    return 1
  }
  if tr -d '\r' <"$REGISTRY" | "$@" | reg_fill_shapes >"$tmp" && [ -s "$tmp" ] && mv "$tmp" "$REGISTRY"; then
    reg_unlock
    return 0
  fi
  rm -f "$tmp"
  reg_unlock
  echo "vellum: could not update the project list ($REGISTRY)" >&2
  return 1
}

# Add a project: name, folder, port, then optionally status, created, closed.
reg_add() {
  local new
  new="$(printf '%s\t%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "${4:-active}" "${5:-$(date '+%Y-%m-%d')}" "${6:-}")"
  reg_update reg_fill_shapes "$new"
}

# Set field number $2 of project $1 to $3, and optionally field $4 to $5, in
# one change.
reg_set() {
  reg_update env REG_N="$1" REG_F="$2" REG_V="$3" REG_F2="${4:-}" REG_V2="${5:-}" LC_ALL=C \
    awk -F'\t' -v OFS='\t' '
      $1 == ENVIRON["REG_N"] {
        $(ENVIRON["REG_F"] + 0) = ENVIRON["REG_V"]
        if (ENVIRON["REG_F2"] != "") $(ENVIRON["REG_F2"] + 0) = ENVIRON["REG_V2"]
      }
      {print}'
}

# Lists written before projects had shapes get them here, once. The status
# line and the list command never write, so this runs for other commands.
reg_migrate() {
  [ -s "$REGISTRY" ] || return 0
  LC_ALL=C awk -F'\t' '$0 !~ /^[[:space:]\r]*$/ && $7 == "" {found = 1; exit} END {exit !found}' "$REGISTRY" || return 0
  reg_update cat
}

# Ports already promised to a project, here or in the earlier project kit.
known_ports() {
  reg_lines | cut -d "$TAB" -f3
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

# "Garden Planner!" becomes "garden-planner", and "Café Menu" "cafe-menu".
# Prints nothing if no plain letter or number is left.
slugify() {
  local s t
  # Line breaks and tabs become spaces, so they cannot split the list's lines.
  s="$(printf '%s' "$1" | LC_ALL=C tr '\n\t\r' '   ')"
  # Take the accents off letters. perl and iconv both come with macOS.
  if command -v perl >/dev/null 2>&1; then
    t="$(printf '%s' "$s" | perl -MEncode -MUnicode::Normalize -e '
      local $/; my $s = decode("UTF-8", scalar(<STDIN>) // "");
      $s =~ s/\x{df}/ss/g; $s =~ s/\x{e6}/ae/g; $s =~ s/\x{c6}/AE/g;
      $s =~ s/\x{153}/oe/g; $s =~ s/\x{152}/OE/g;
      $s =~ tr/\x{f8}\x{d8}\x{111}\x{110}\x{142}\x{141}/oOdDlL/;
      $s = NFD($s); $s =~ s/\p{Mn}+//g; $s =~ s/[^\x00-\x7f]/-/g;
      print $s' 2>/dev/null)" && s="$t"
  elif command -v iconv >/dev/null 2>&1; then
    t="$(printf '%s' "$s" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | LC_ALL=C tr -d "'\"^\`~")" && [ -n "$t" ] && s="$t"
  fi
  s="$(printf '%s' "$s" | LC_ALL=C tr '[:upper:]' '[:lower:]' |
    LC_ALL=C sed 's/[^a-z0-9._-]/-/g; s/--*/-/g; s/^[-.]*//' | cut -c1-80 | LC_ALL=C sed 's/[-.]*$//')"
  case "$s" in *[0-9a-z]*) printf '%s' "$s" ;; esac
}

# Turn what the person called a project into its registered name. Accepts the
# exact name, any capitalisation, or a unique part of a name.
resolve_project() {
  local query="$1" lower matches count
  [ -n "$query" ] || die "say which project"
  [ -n "$(reg_lines)" ] || die "there are no projects yet. Say 'start a new project called ...' or 'import my projects'."
  # Compare in the stored form, so "Patio Planner" finds patio-planner.
  lower=$(slugify "$query")
  [ -n "$lower" ] || die "there is no project called '$query'. Say 'list my projects' to see them."
  matches=$(reg_lines | REG_Q="$lower" LC_ALL=C awk -F'\t' '
    {s = tolower($1); gsub(/[^a-z0-9._-]+/, "-", s)} s == ENVIRON["REG_Q"] {print $1}')
  if [ -z "$matches" ]; then
    matches=$(reg_lines | REG_Q="$lower" LC_ALL=C awk -F'\t' '
      {s = tolower($1); gsub(/[^a-z0-9._-]+/, "-", s)} index(s, ENVIRON["REG_Q"]) {print $1}')
  fi
  count=$(printf '%s' "$matches" | grep -c . || true)
  if [ "$count" -eq 1 ]; then
    echo "$matches"
    return 0
  fi
  if [ "$count" -gt 1 ]; then
    echo "vellum: '$query' matches more than one project:" >&2
    printf '%s\n' "$matches" | sed 's/^/  /' >&2
    exit 1
  fi
  if [ -d "$(projects_dir)/$query" ]; then
    die "'$query' is a folder in $(projects_dir) but not on the project list. Say 'add $query to my projects'."
  fi
  die "there is no project called '$query'. Say 'list my projects' to see them."
}

# Record that this Claude session worked on a project, so the curator
# organises that project's journal when the session ends. The last line is
# always the project worked on most recently; the status line reads it.
remember_session() {
  local session="$1" path="$2" file tmp
  [ -n "$session" ] && [ -n "$path" ] || return 0
  # The home and projects folders are not projects.
  [ "$path" != "$HOME_P" ] && [ "$path" != "$(projects_dir)" ] || return 0
  session=$(__sanitize "$session")
  mkdir -p "$SESSIONS" 2>/dev/null || return 0
  file="$SESSIONS/$session"
  [ -f "$file" ] && [ "$(tail -1 "$file")" = "$path" ] && return 0
  tmp="$(mktemp "$file.XXXXXX" 2>/dev/null)" || return 0
  {
    [ -f "$file" ] && grep -vxF -- "$path" "$file"
    echo "$path"
  } >"$tmp"
  mv "$tmp" "$file" 2>/dev/null || rm -f "$tmp"
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

# Replace a leading folder path in each line with a short name, without
# treating either as a pattern (paths can hold | or other symbols).
strip_prefix() {
  PFX="$1" NEW="$2" LC_ALL=C awk '
    index($0, ENVIRON["PFX"]) == 1 {$0 = ENVIRON["NEW"] substr($0, length(ENVIRON["PFX"]) + 1)} {print}'
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

# The kit's weekly job for a project, a LaunchAgent named
# <prefix>.design-journal-weekly-<project>.plist. Prints nothing if there is none.
kit_weekly_job() {
  local f
  for f in "$HOME/Library/LaunchAgents/"*.design-journal-weekly-"$1".plist; do
    [ -f "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

# How many of the kit's projects still have a folder.
kit_project_count() {
  local name port n=0 pdir
  pdir="$(projects_dir)"
  while IFS="$TAB" read -r name port; do
    [ -n "$name" ] && [ -d "$pdir/$name" ] && n=$((n + 1))
  done <<EOF
$(kit_ports)
EOF
  echo "$n"
}

# A registered name for a slug that no project uses yet: garden, then
# garden-2, garden-3 and so on.
free_name() {
  local base="$1" name i=2
  [ -n "$base" ] || base="project"
  name="$base"
  while [ -n "$(reg_name_matching "$name")" ]; do
    name="$base-$i"
    i=$((i + 1))
  done
  echo "$name"
}

# Take the kit's hooks out of a project's .claude/settings.json and stop its
# weekly job, because Vellum now does both. Keeps backups.
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
  plist="$(kit_weekly_job "$name")" || plist=""
  if [ -n "$plist" ]; then
    launchctl unload "$plist" 2>/dev/null || true
    mkdir -p "$VELLUM_HOME/retired"
    mv "$plist" "$VELLUM_HOME/retired/"
    echo "Stopped the project kit's weekly job (moved to ~/.vellum/retired/). The curator writes weekly round-ups now."
  elif has_kit_hooks "$root" || [ -f "$settings.kit-backup" ]; then
    echo "There was no project kit weekly job for this project, so none was stopped."
  fi
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_new() {
  parse_session "$@"
  local name about="" dir port i=0 arg existing words=() has_git=0
  case "${ARGS[0]:-}" in
    -*) die "say what the project is called first, for example: vellum new \"Garden Planner\" --about \"Plans a vegetable garden.\"" ;;
  esac
  while [ $i -lt ${#ARGS[@]} ]; do
    arg="${ARGS[$i]}"
    case "$arg" in
      --about) about="${ARGS[$((i + 1))]:-}"; i=$((i + 2)); continue ;;
      --about=*) about="${arg#--about=}" ;;
      -*) die "unknown option '$arg'. new takes a name and, if you like, --about TEXT" ;;
      *) words+=("$arg") ;;
    esac
    i=$((i + 1))
  done
  [ -n "${words[*]:-}" ] || die "say what the project is called"
  name="$(slugify "${words[*]}")"
  [ -n "$name" ] || die "that name has nothing a folder name can use: $SLUG_HINT"
  existing="$(reg_name_matching "$name")"
  [ -z "$existing" ] || die "there is already a project called $existing. Say 'open $existing' to work on it."
  dir="$(projects_dir)/$name"
  if [ -e "$dir" ]; then
    existing="$(reg_name_for_path "$dir")"
    [ -n "$existing" ] && die "$dir is already on the project list as $existing. Say 'open $existing' to work on it."
    die "$dir already exists. Say 'add $name to my projects' to use it."
  fi

  mkdir -p "$dir" 2>/dev/null || die "could not create $dir. Check that $(projects_dir) exists and can be written to."
  dir="$(cd "$dir" && pwd -P)" || die "could not open $dir"
  if command -v git >/dev/null 2>&1 && (cd "$dir" && git init -q) >/dev/null 2>&1; then
    has_git=1
  fi
  {
    echo "# $name"
    [ -n "$about" ] && printf '\n%s\n' "$about"
  } >"$dir/README.md"
  printf '.DS_Store\nnode_modules/\ndist/\n.env\n.env.*\n!.env.example\n' >"$dir/.gitignore"

  set_project "$dir"
  seed_journal "$JOURNAL"
  if [ -n "$about" ]; then
    ABOUT="$about" awk '/^Not written yet/ {print ENVIRON["ABOUT"]; next} {print}' "$JOURNAL/overview.md" >"$JOURNAL/overview.tmp"
    mv "$JOURNAL/overview.tmp" "$JOURNAL/overview.md"
  fi
  build_index "$JOURNAL"
  add_git_exclude "$dir"

  port="$(next_port)"
  reg_add "$name" "$dir" "$port" || die "made $dir, but could not add it to the project list. Say 'add $name to my projects' to try again."
  remember_session "$SESSION_ID" "$dir"

  echo "Started $name."
  echo "  folder: $dir"
  echo "  port:   $port (for a local web server, if it needs one)"
  if [ $has_git -eq 1 ]; then
    echo "  It has git, a README and a journal. The journal is kept out of git."
  else
    echo "  It has a README and a journal. git could not be set up, so it has no version history yet."
  fi
  echo
  echo "From now on, run every command for this project inside $dir (cd there first)."
  echo
  project_context
}

cmd_open() {
  parse_session "$@"
  local name line dir
  name="$(resolve_project "${ARGS[*]:-}")" || exit 1
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
    echo "It has no journal yet. Ask the person whether to start one; if yes, run vellum init inside $dir."
    return 0
  fi
  project_context
}

cmd_list() {
  local all=0 name dir port status created closed shape last summary when hidden=0 n
  [ "${1:-}" = "--all" ] && all=1
  if [ -z "$(reg_lines)" ]; then
    echo "There are no projects on the list yet."
    n="$(kit_project_count)"
    [ "$n" -gt 0 ] && echo "Your project kit has $n project(s). Say 'import my projects' to bring them in."
    return 0
  fi
  # Newest work first. Each line is read once; the unit separator keeps empty
  # fields in place, which a tab would not.
  while IFS=$'\037' read -r name dir port status created closed shape _; do
    [ -n "$name" ] || continue
    if [ "$status" = "closed" ] && [ $all -eq 0 ]; then
      continue
    fi
    last=""; summary=""
    if [ -d "$dir" ]; then
      set_project "$dir"
      last="$(last_worked "$JOURNAL")"
      summary="$(project_summary "$JOURNAL")"
      when="no sessions yet"
      [ -n "$last" ] && when="last worked on $last"
    else
      when="folder missing: $dir"
    fi
    printf '%s\t%s\n' "${last:-0000-00-00}" "$shape $name  (port $port, $when${closed:+, closed $closed})${summary:+$TAB$summary}"
  done < <(reg_lines | reg_fill_shapes | tr '\t' '\037') | sort -r | cut -f2- | while IFS="$TAB" read -r head summary; do
    echo "$head"
    [ -n "$summary" ] && echo "    $summary"
  done
  if [ $all -eq 0 ]; then
    hidden=$(reg_lines | awk -F'\t' '$4 == "closed"' | grep -c . || true)
    [ "$hidden" -gt 0 ] && echo "($hidden closed project(s) not shown. Say 'list all my projects' to see them.)"
  fi
  return 0
}

cmd_rename() {
  local name new line dir target here existing
  [ $# -le 2 ] || die "rename takes two names, the old one and the new one. Put each name in quotes if it has spaces, for example: vellum rename \"Garden Planner\" \"Veg Plot\""
  [ -n "${1:-}" ] || die "say which project to rename"
  name="$(resolve_project "$1")" || exit 1
  [ -n "${2:-}" ] || die "say the new name"
  new="$(slugify "$2")"
  [ -n "$new" ] || die "that new name has nothing a folder name can use: $SLUG_HINT"
  [ "$new" != "$name" ] || die "$name is already called that"
  existing="$(reg_name_matching "$new")"
  [ -z "$existing" ] || [ "$existing" = "$name" ] || die "there is already a project called $existing"
  line="$(reg_line "$name")"
  dir="$(field "$line" 2)"
  [ -d "$dir" ] || die "$name's folder, $dir, is missing, so it cannot be renamed. It may have been moved or deleted."
  target="$(dirname "$dir")/$new"
  [ -e "$target" ] && die "$target already exists"
  here="$(pwd)"

  mv "$dir" "$target" 2>/dev/null || die "could not move $dir to $target, so nothing was renamed"
  reg_set "$name" 2 "$target" 1 "$new" || die "moved the folder to $target, but could not update the project list"

  set_project "$target"
  if [ -d "$JOURNAL/logbook" ]; then
    printf '\n## Renamed from %s to %s\n\nThe project folder moved from `%s` to `%s`.\n' "$name" "$new" "$dir" "$target" >>"$JOURNAL/logbook/$(date '+%Y-%m-%d').md"
  fi
  echo "Renamed $name to $new."
  echo "  folder: $target"
  case "$here/" in "$dir"/*) echo "  The shell was inside the old folder. cd $target before running anything else." ;; esac
  kit_weekly_job "$name" >/dev/null && echo "  The project kit's weekly job still uses the old name. Say 'adopt $new' to retire it."
  if (cd "$target" && git remote get-url origin >/dev/null 2>&1); then
    echo "  The GitHub repository still has its old name. Rename it on GitHub if you want them to match."
  fi
  return 0
}

cmd_close() {
  local name line dir archive=1 arg words=() err reason
  for arg in "$@"; do
    case "$arg" in
      --no-archive) archive=0 ;;
      *) words+=("$arg") ;;
    esac
  done
  name="$(resolve_project "${words[*]:-}")" || exit 1
  line="$(reg_line "$name")"
  dir="$(field "$line" 2)"
  [ "$(field "$line" 4)" = "closed" ] && die "$name is already closed"

  if [ ! -d "$dir" ]; then
    echo "$name's folder, $dir, is missing, so no archive was made."
  elif [ $archive -eq 1 ]; then
    set_project "$dir"
    if [ ! -d "$JOURNAL" ]; then
      :
    elif [ $(( $(count_md "$JOURNAL/logbook") + $(count_md "$JOURNAL/decisions") + $(count_md "$JOURNAL/experiments") )) -eq 0 ]; then
      echo "The journal is empty, so there was nothing to archive."
    else
      err="$(mktemp)"
      if ! (cd "$dir" && cmd_archive) 2>"$err"; then
        reason="$(sed -n '1s/^vellum: //p' "$err")"
        echo "The archive could not be made${reason:+ ($reason)}, so the project was closed without one."
      fi
      rm -f "$err"
    fi
  fi
  reg_set "$name" 4 closed 6 "$(date '+%Y-%m-%d')" || die "could not update the project list, so $name is still open"
  echo "Closed $name. Its folder and journal are kept. Say 'reopen $name' to bring it back."
  if port_in_use "$(field "$line" 3)"; then
    echo "It is still running on port $(field "$line" 3). Say 'stop $name' to stop it."
  fi
  return 0
}

cmd_reopen() {
  local name
  name="$(resolve_project "$*")" || exit 1
  if [ "$(field "$(reg_line "$name")" 4)" != "closed" ]; then
    echo "$name is already open."
    return 0
  fi
  reg_set "$name" 4 active 6 "" || die "could not update the project list, so $name is still closed"
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
  [ "$dir" != "/" ] || die "the top folder of the disk (/) cannot be a project"
  [ "$dir" != "$HOME_P" ] || die "your home folder cannot be a project"
  [ "$dir" != "$(projects_dir)" ] || die "the projects folder itself cannot be a project. Say which folder inside it to add."
  [ -w "$dir" ] || die "$dir cannot be written to, so it cannot hold a journal"

  existing="$(reg_name_for_path "$dir")"
  if [ -n "$existing" ]; then
    name="$existing"
    echo "$name is already on the project list."
  else
    name="$(free_name "$(slugify "$(basename "$dir")")")"
    port="$(kit_ports | KIT_N="$(basename "$dir")" awk -F'\t' '$1 == ENVIRON["KIT_N"] && $2 ~ /^[0-9]+$/ {print $2; exit}')"
    [ -n "$port" ] || port="$(next_port)"
    reg_add "$name" "$dir" "$port" || die "could not add $dir to the project list"
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
# Names are made folder-safe here ("My Site" becomes my-site); the kit's own
# name is still used to find the folder.
cmd_import_kit() {
  local added=0 kitname port dir name names="" pdir
  pdir="$(projects_dir)"
  if [ -z "$(kit_ports)" ]; then
    echo "No project kit was found in $pdir."
    return 0
  fi
  while IFS="$TAB" read -r kitname port; do
    [ -n "$kitname" ] || continue
    dir="$pdir/$kitname"
    [ -d "$dir" ] || continue
    dir="$(cd "$dir" && pwd -P)" || continue
    [ -n "$(reg_name_for_path "$dir")" ] && continue
    name="$(free_name "$(slugify "$kitname")")"
    # The kit sometimes left a project without a port (null).
    case "$port" in ''|*[!0-9]*) port="$(next_port)" ;; esac
    reg_add "$name" "$dir" "$port" || die "could not add $name to the project list"
    added=$((added + 1))
    names="${names:+$names, }$name"
  done <<EOF
$(kit_ports)
EOF
  if [ $added -eq 0 ]; then
    echo "Added 0 project(s): every project kit project still on disk is already on the list."
  else
    echo "Added $added project(s) from the project kit: $names."
  fi
  echo
  cmd_list
}

cmd_running() {
  local name dir port pids out=""
  command -v lsof >/dev/null 2>&1 || die "lsof is not available, so running servers cannot be checked"
  [ -n "$(reg_lines)" ] || { echo "There are no projects on the list yet."; return 0; }
  while IFS=$'\037' read -r name dir port _; do
    case "$port" in ''|*[!0-9]*) continue ;; esac
    pids="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | tr '\n' ' ' | sed 's/ *$//')"
    [ -n "$pids" ] && out="$out$name is running at http://localhost:$port (process $pids)
"
  done < <(reg_lines | tr '\t' '\037')
  if [ -n "$out" ]; then printf '%s' "$out"; else echo "None of your projects is running."; fi
  return 0
}

# Stop a project's local server. Only processes running from inside the
# project's folder are stopped, so an unrelated program that happens to use
# the same port is left alone.
cmd_stop() {
  local name line dir port pids pid cwd ours="" others=""
  name="$(resolve_project "$*")" || exit 1
  command -v lsof >/dev/null 2>&1 || die "lsof is not available, so running servers cannot be checked"
  line="$(reg_line "$name")"
  dir="$(field "$line" 2)"
  port="$(field "$line" 3)"
  case "$port" in ''|*[!0-9]*) die "$name has no port on the list, so there is nothing to stop" ;; esac
  dir="$( (cd "$dir" 2>/dev/null && pwd -P) || echo "$dir")"
  pids="$(lsof -nP -iTCP:"$port" -sTCP:LISTEN -t 2>/dev/null | sort -u)"
  [ -n "$pids" ] || { echo "$name is not running."; return 0; }
  for pid in $pids; do
    cwd="$(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
    case "$cwd/" in
      "$dir"/*) ours="$ours $pid" ;;
      *) others="$others $pid" ;;
    esac
  done
  if [ -n "$others" ]; then
    [ -n "$ours" ] || echo "Port $port is in use, but not by $name, so nothing was stopped:"
    [ -n "$ours" ] && echo "Port $port is also in use by something outside $name, which was left alone:"
    for pid in $others; do
      echo "  process $pid: $(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown program"), running in $(lsof -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -1)"
    done
    [ -n "$ours" ] || exit 1
  fi
  # shellcheck disable=SC2086  # one or more process ids
  kill $ours 2>/dev/null || die "could not stop $name (process$ours on port $port). It may belong to another user."
  echo "Stopped $name (port $port)."
}

# Search every project's journal and the archive library.
cmd_search() {
  local query="$*" name dir hits total=0
  [ -n "$query" ] || die "say what to search for"
  while IFS=$'\037' read -r name dir _; do
    [ -n "$name" ] && [ -d "$dir" ] || continue
    set_project "$dir"
    [ -d "$JOURNAL" ] || continue
    hits="$(grep -rinIF --include='*.md' -- "$query" "$JOURNAL" 2>/dev/null | grep -vF '/INDEX.md:' | head -8)"
    [ -n "$hits" ] || continue
    echo "## $name"
    printf '%s\n' "$hits" | strip_prefix "$JOURNAL/" "$JOURNAL_NAME/" | cut -c1-220
    echo
    total=$((total + 1))
  done < <(reg_lines | tr '\t' '\037')
  if [ -d "$LIBRARY" ]; then
    hits="$(grep -rinIF -- "$query" "$LIBRARY" 2>/dev/null | head -8)"
    if [ -n "$hits" ]; then
      echo "## Archived projects"
      printf '%s\n' "$hits" | strip_prefix "$LIBRARY/" "library/" | cut -c1-220
      total=$((total + 1))
    fi
  fi
  [ $total -gt 0 ] || echo "Nothing in any journal mentions \"$query\"."
  return 0
}

# What happened across every active project in the last N days.
cmd_digest() {
  local days="${1:-7}" since name dir status f found=0 any
  case "$days" in
    ''|*[!0-9]*) die "say how many days to look back as a number, for example: vellum digest 7" ;;
  esac
  since="$(date -v-"${days}"d '+%Y-%m-%d')"
  [ -n "$(reg_lines)" ] || { echo "There are no projects on the list yet."; return 0; }
  echo "Work since $since:"
  while IFS=$'\037' read -r name dir _ status _; do
    [ "$status" = "active" ] && [ -d "$dir" ] || continue
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
  done < <(reg_lines | tr '\t' '\037')
  [ $found -eq 1 ] || echo "No journal entries in that time."
  return 0
}

# Checks before code is pushed anywhere. Exits 1 if anything needs attention.
# With --public, a missing licence counts as something to fix.
cmd_preship() {
  local root issues=0 hits remote patterns public=0 arg vis
  for arg in "$@"; do
    case "$arg" in
      --public) public=1 ;;
      *) die "unknown option '$arg'. preship takes --public (checks for a public repository) or nothing" ;;
    esac
  done
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "this folder is not a git repository"
  cd "$root" || exit 1
  set_project "$root"
  warn() { echo "  check  $1"; issues=$((issues + 1)); }
  ok() { echo "  ok     $1"; }

  echo "Before you push $(basename "$root"):"
  [ -f README.md ] && ok "README.md is there" || warn "there is no README.md"
  if [ -f LICENSE ] || [ -f LICENSE.md ] || [ -f LICENSE.txt ]; then
    ok "there is a licence"
  elif [ $public -eq 1 ]; then
    warn "there is no LICENSE file, so others may not reuse the code"
  else
    echo "  note   there is no LICENSE file. That is fine while the repository is private; add one before making it public."
  fi

  patterns='(AWS_SECRET_ACCESS_KEY|AKIA[0-9A-Z]{16}|[Aa][Pp][Ii][_-]?[Kk][Ee][Yy][[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9_-]{16,}|BEGIN (RSA|OPENSSH|DSA|EC) PRIVATE KEY|Bearer [A-Za-z0-9_.-]{20,}|sk-[A-Za-z0-9_-]{32,}|[sr]k_live_[A-Za-z0-9]{16,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|xox[bp]-[A-Za-z0-9-]{20,})'
  hits="$(git ls-files -z | xargs -0 grep -lE "$patterns" 2>/dev/null | grep -v '\.example$' || true)"
  if [ -n "$hits" ]; then warn "these files may contain passwords or keys:"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "no passwords or keys found in tracked files"; fi

  hits="$(git ls-files | grep -E '(^|/)\.env($|\.)' | grep -v '\.example$' || true)"
  if [ -n "$hits" ]; then warn ".env files are tracked by git:"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "no .env files are tracked"; fi

  hits="$(git ls-files | grep -E '^(client-data|private)/' | head -5 || true)"
  if [ -n "$hits" ]; then warn "files in client-data/ or private/ are tracked"; else ok "nothing in client-data/ or private/ is tracked"; fi

  if [ "$JOURNAL_NAME" = ".vellum" ] && [ -n "$(git ls-files .vellum | head -1)" ]; then
    warn "the private journal in .vellum/ is tracked by git"
  else
    ok "the private journal is not tracked"
  fi

  # du separates the size from the name with a tab, so names with spaces survive.
  hits="$(git ls-files -z | xargs -0 du -k 2>/dev/null | awk -F'\t' '$1 > 5120 {print $2}' | head -5 || true)"
  if [ -n "$hits" ]; then warn "these files are over 5 MB:"; printf '%s\n' "$hits" | sed 's/^/           /'; else ok "no files over 5 MB"; fi

  remote="$(git remote get-url origin 2>/dev/null || true)"
  if [ -z "$remote" ]; then
    echo "  note   there is no GitHub repository yet"
  elif command -v gh >/dev/null 2>&1; then
    vis="$(gh repo view "$remote" --json visibility -q .visibility 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    echo "  note   pushes go to $remote (${vis:-visibility unknown})"
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

# Create a GitHub repository for the current project and push it. The
# repository takes the project's name on the list, or a folder-safe form of
# the folder's name.
cmd_publish() {
  local root name visibility="--private" arg
  for arg in "$@"; do
    case "$arg" in
      --public) visibility="--public" ;;
      --private) visibility="--private" ;;
      *) die "unknown option '$arg'. Say 'vellum publish' for a private repository, or 'vellum publish --public' for a public one." ;;
    esac
  done
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || die "this folder is not a git repository"
  command -v gh >/dev/null 2>&1 || die "the GitHub command line tool (gh) is not installed. Install it with 'brew install gh'."
  gh auth status >/dev/null 2>&1 || die "you are not signed in to GitHub. Run 'gh auth login' in Terminal first."
  cd "$root" || exit 1
  git remote get-url origin >/dev/null 2>&1 && die "this project already has a remote: $(git remote get-url origin)"
  git rev-parse HEAD >/dev/null 2>&1 || die "there are no commits yet, so there is nothing to push"
  if [ "$visibility" = "--public" ]; then
    cmd_preship --public || die "fix the checks above first"
  else
    cmd_preship || die "fix the checks above first"
  fi
  name="$(slugify "$(reg_name_for_path "$root")")"
  [ -n "$name" ] || name="$(slugify "$(basename "$root")")"
  [ -n "$name" ] || name="project"
  gh repo create "$name" "$visibility" --source=. --remote=origin --push ||
    die "GitHub did not create the repository $name, so nothing was published. The message above says why (for example, the name may already be taken)."
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
  REG_D="$d/" LC_ALL=C awk -F'\t' '{sub(/\r$/, "")} $2 != "" && index(ENVIRON["REG_D"], $2 "/") == 1 && length($2) > best {best = length($2); name = $1} END {if (name != "") print name}' "$REGISTRY"
}

# Each project keeps its own shape, stored on the project list (column 7) when
# the project is added. A project on an older list without one is shown the
# shape it will be given, without writing it. Folders not on the list get one
# from their name.
project_shape() {
  local name="$1" shape n
  if [ -n "$(reg_line "$name")" ]; then
    shape="$(reg_lines | reg_fill_shapes | REG_N="$name" LC_ALL=C awk -F'\t' '$1 == ENVIRON["REG_N"] {print $7; exit}')"
    echo "$shape"
    return 0
  fi
  n=$(printf '%s' "$name" | cksum | cut -d' ' -f1)
  # shellcheck disable=SC2086  # split the shapes into words
  set -- $SHAPES
  shift $(( (n / 7) % $# ))
  echo "$1"
}

# Each project gets its own colour, the same every time. Only the terminal's six
# standard colours are used (31 red to 36 cyan): every theme sets those to suit
# its own background, so they stay readable whatever theme is chosen.
project_colour() {
  local colours="36 35 33 32 34 31" n
  n=$(printf '%s' "$1" | cksum | cut -d' ' -f1)
  set -- $colours
  shift $(( n % $# ))
  echo "$1"
}

# Print text in a terminal style (a colour from 31 to 36, or 1 for bold), unless
# the person has switched colour off with NO_COLOR.
paint() {
  if [ -n "${NO_COLOR:-}" ]; then
    printf '%s' "$2"
  else
    printf '\033[%sm%s\033[0m' "$1" "$2"
  fi
}

# Is something serving this port? Cached for 15 seconds, because the status
# line redraws often and lsof is slow.
port_running_cached() {
  local port="$1" cache="$VELLUM_HOME/.cache/port-$1" now
  now=$(date +%s)
  mkdir -p "$VELLUM_HOME/.cache" 2>/dev/null || return 1
  if [ -f "$cache" ] && [ $((now - $(stat -f %m "$cache" 2>/dev/null || echo 0))) -lt 15 ]; then
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
  # A git worktree belongs to its main copy's project.
  root="$(project_root "$cwd")"
  [ -n "$name" ] || name="$(reg_name_containing "$root")"
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
    # The home and projects folders are not projects.
    [ "$root" != "$HOME_P" ] && [ "$root" != "$(projects_dir)" ] || return 0
    set_project "$root"
    case "$root/" in "$(projects_dir)"/*) ;; *) [ -d "$JOURNAL" ] || return 0 ;; esac
    dir="$root"
    name="$(basename "$root")"
    port="$(kit_ports | KIT_N="$name" awk -F'\t' '$1 == ENVIRON["KIT_N"] && $2 ~ /^[0-9]+$/ {print $2; exit}')"
  fi
  set_project "$dir"
  remember_session "$session" "$dir"

  colour="$(project_colour "$name")"
  # The shape takes the colour; the name stays in the theme's own text colour,
  # in bold, so it is always as readable as everything else.
  out="$(paint "$colour" "$(project_shape "$name")") $(paint 1 "$name")"

  if [ -n "$port" ] && port_running_cached "$port"; then
    out="$out  $(paint 32 "live on :$port")"
  fi

  if [ -e "$dir/.git" ]; then
    branch="$(git -C "$dir" branch --show-current 2>/dev/null)"
    case "$branch" in
      ""|main|master) ;;
      *) out="$out  $branch" ;;
    esac
    ahead="$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null || true)"
    [ -n "$ahead" ] && [ "$ahead" -gt 0 ] && out="$out  $(paint 33 "$ahead to push")"
  fi

  [ -f "$JOURNAL/.paused" ] && out="$out  $(paint 33 "journal paused")"

  printf '%s' "$out"
}
