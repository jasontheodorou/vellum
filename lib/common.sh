#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# Shared helpers, settings and per-project state.

# Set while the curator runs, so its own session does not start another.
# CLAUDE_JOURNAL_HOOK is the name the pre-plugin version used.
is_helper_session() {
  [ "${VELLUM_SUBAGENT:-0}" = "1" ] || [ "${CLAUDE_JOURNAL_HOOK:-0}" = "1" ]
}

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

log() {
  mkdir -p "$VELLUM_HOME" 2>/dev/null || return 0
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$GLOBAL_LOG" 2>/dev/null || true
}

die() { echo "vellum: $*" >&2; exit 1; }

plugin_version() {
  sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -1
}

# Read a top-level string field from a JSON object. Uses jq when present,
# otherwise a simple pattern that is enough for the flat hook payloads.
json_field() {
  local json="$1" key="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r --arg k "$key" '.[$k] // empty' 2>/dev/null
    return 0
  fi
  printf '%s' "$json" | tr -d '\n' |
    sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

# The project root: the git top level if there is one, otherwise the directory.
# Always the resolved path (pwd -P), the form Claude Code reports, so the same
# folder is never mistaken for two (on macOS, /tmp is really /private/tmp).
#
# Two kinds of repository are not projects:
# - one in the home folder (some people keep their settings files in git) or
#   in the projects folder. Below those, the folder itself is the project, or
#   the first folder below the projects folder.
# - a git worktree, which is a second working copy of a project. It belongs to
#   the main copy, so it uses the main copy's journal.
project_root() {
  local dir="${1:-$PWD}" top common pdir rest
  dir="$( (cd "$dir" 2>/dev/null && pwd -P) || echo "$dir")"
  [ -d "$dir" ] || { echo "$dir"; return 0; }
  command -v git >/dev/null 2>&1 || { echo "$dir"; return 0; }
  top="$(cd "$dir" && git rev-parse --show-toplevel 2>/dev/null)" || top=""
  [ -n "$top" ] || { echo "$dir"; return 0; }
  top="$( (cd "$top" 2>/dev/null && pwd -P) || echo "$top")"

  # A worktree's shared .git folder is in the main copy. git prints it relative
  # to the current folder, so resolve it from there (older git has no
  # --path-format option).
  common="$(cd "$dir" && git rev-parse --git-common-dir 2>/dev/null)" || common=""
  if [ -n "$common" ]; then
    common="$(cd "$dir" && cd "$common" 2>/dev/null && pwd -P)" || common=""
    if [ -n "$common" ] && [ "$(basename "$common")" = ".git" ] && [ "$(dirname "$common")" != "$top" ]; then
      top="$(dirname "$common")"
    fi
  fi

  pdir="$(projects_dir 2>/dev/null)" || pdir=""
  if [ "$top" = "$HOME_P" ] || { [ -n "$pdir" ] && [ "$top" = "$pdir" ]; }; then
    if [ -n "$pdir" ] && [ "$dir" != "$pdir" ]; then
      case "$dir/" in
        "$pdir"/*)
          rest="${dir#"$pdir"/}"
          echo "$pdir/${rest%%/*}"
          return 0
          ;;
      esac
    fi
    echo "$dir"
    return 0
  fi
  echo "$top"
}

# Print a file's body without its YAML frontmatter.
strip_frontmatter() {
  awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm {print}' "$1"
}

# Turn the first top-level heading into a third-level one.
demote_first_heading() {
  awk '!done && /^# / {sub(/^# /, "### "); done=1} {print}'
}

# Move every heading down one level, so a file's sections sit inside the
# archive's own sections.
demote_headings() {
  sed 's/^\(#\{1,5\}\) /\1# /'
}

# Print at most N lines of a file, with a note if it was cut.
head_with_note() {
  local file="$1" max="$2" total
  total=$(wc -l <"$file" | tr -d ' ')
  head -n "$max" "$file"
  if [ "$total" -gt "$max" ]; then
    echo
    echo "(Cut at $max of $total lines. Read $file for the rest.)"
  fi
}

__sanitize() {
  echo "${1:-}" | sed 's/[^A-Za-z0-9._-]/_/g; s/__*/_/g; s/^_//; s/_$//'
}

__desktop_path() {
  # Tests send archives somewhere other than the real desktop.
  if [ -n "${VELLUM_DESKTOP:-}" ]; then
    mkdir -p "$VELLUM_DESKTOP" && echo "$VELLUM_DESKTOP"
    return 0
  fi
  if [ -d "$HOME/Desktop" ]; then
    echo "$HOME/Desktop"
    return 0
  fi
  echo "$HOME"
  echo "vellum: could not find a Desktop folder, so using your home folder" >&2
}

# ---------------------------------------------------------------------------
# Settings (~/.vellum/config, one key=value per line)
# ---------------------------------------------------------------------------

config_get() {
  local key="$1" default="${2:-}" value=""
  if [ -f "$CONFIG" ]; then
    value=$(awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, ""); v=$0} END {print v}' "$CONFIG")
  fi
  [ -n "$value" ] && echo "$value" || echo "$default"
}

config_set() {
  local key="$1" value="$2"
  mkdir -p "$VELLUM_HOME"
  touch "$CONFIG"
  grep -v "^$key=" "$CONFIG" >"$CONFIG.tmp" || true
  echo "$key=$value" >>"$CONFIG.tmp"
  mv "$CONFIG.tmp" "$CONFIG"
}

cmd_config() {
  local key="${1:-}" value="${2:-}"
  if [ -z "$key" ]; then
    echo "background   = $(config_get background on)"
    echo "model        = $(config_get model default)"
    echo "projects-dir = $(config_get projects-dir "$HOME/projects")"
    return 0
  fi
  case "$key" in
    background)
      [ -z "$value" ] && { config_get background on; return 0; }
      case "$value" in
        on|off) config_set background "$value" ;;
        *) die "background must be 'on' or 'off'" ;;
      esac
      if [ "$value" = "off" ]; then
        echo "The background curator is off. Claude still writes the journal during sessions."
      else
        echo "The background curator is on. It organises the journal after each session."
      fi
      ;;
    model)
      [ -z "$value" ] && { config_get model default; return 0; }
      config_set model "$value"
      echo "The background curator and archive summaries will use the model: $value"
      ;;
    projects-dir)
      [ -z "$value" ] && { config_get projects-dir "$HOME/projects"; return 0; }
      # A ~ inside quotes reaches here as it is, so expand it by hand.
      case "$value" in
        "~") value="$HOME" ;;
        "~/"*) value="$HOME/${value#"~/"}" ;;
      esac
      mkdir -p "$value" || die "could not create $value"
      value="$(cd "$value" && pwd)" || die "could not open $value"
      config_set projects-dir "$value"
      echo "New projects will go in $value."
      ;;
    *) die "unknown setting '$key' (settings: background, model, projects-dir)" ;;
  esac
}

# ---------------------------------------------------------------------------
# Moving from Scribe
# ---------------------------------------------------------------------------

# Move Scribe's data from ~/.scribe to ~/.vellum, once. Anything already in
# ~/.vellum wins. The old curl install's own files stay behind for
# remove-old-install, and ~/.scribe goes once it is empty.
migrate_home() {
  local item to
  [ -d "$OLD_HOME" ] && [ ! -e "$VELLUM_HOME/.moved-from-scribe" ] || return 0
  mkdir -p "$VELLUM_HOME" 2>/dev/null || return 0
  # Only one process moves things, even when several start at once. A marker
  # older than a minute was left by a move that was interrupted, so try again.
  if ! mkdir "$VELLUM_HOME/.moving" 2>/dev/null; then
    [ $(( $(date +%s) - $(stat -f %m "$VELLUM_HOME/.moving" 2>/dev/null || date +%s) )) -gt 60 ] || return 0
    rmdir "$VELLUM_HOME/.moving" 2>/dev/null || return 0
    mkdir "$VELLUM_HOME/.moving" 2>/dev/null || return 0
  fi
  for item in library sessions notices recall retired .cache config declined projects.tsv scribe.log; do
    [ -e "$OLD_HOME/$item" ] || continue
    to="$VELLUM_HOME/$item"
    [ "$item" = "scribe.log" ] && to="$GLOBAL_LOG"
    [ -e "$to" ] || mv "$OLD_HOME/$item" "$to" 2>/dev/null || true
  done
  : >"$VELLUM_HOME/.moved-from-scribe"
  rmdir "$VELLUM_HOME/.moving" "$OLD_HOME" 2>/dev/null || true
}

# Rename a project's Scribe journal, .scribe/, to .vellum/. Home is skipped,
# because ~/.scribe there is the old data folder, not a journal.
migrate_project_journal() {
  local root="$1" exclude
  [ "$root" != "$HOME" ] && [ "$root" != "$HOME_P" ] || return 0
  [ -d "$root/.scribe" ] && [ ! -e "$root/.vellum" ] || return 0
  [ -f "$root/.scribe/overview.md" ] || [ -d "$root/.scribe/logbook" ] || return 0
  mv "$root/.scribe" "$root/.vellum" 2>/dev/null || return 0
  [ -f "$root/.scribe-declined" ] && mv "$root/.scribe-declined" "$root/.vellum-declined"
  exclude=$(git_exclude_file "$root") || return 0
  if [ -f "$exclude" ] && grep -qxF "/.scribe/" "$exclude"; then
    sed 's#^/\.scribe/$#/.vellum/#' "$exclude" >"$exclude.tmp" && mv "$exclude.tmp" "$exclude"
  fi
  log "moved $root/.scribe to .vellum"
}

# ---------------------------------------------------------------------------
# Per-project state
# ---------------------------------------------------------------------------

is_declined() {
  local root="$1"
  [ -f "$root/.vellum-declined" ] || [ -f "$root/.scribe-declined" ] && return 0
  [ -f "$DECLINED" ] && grep -qxF "$root" "$DECLINED"
}

# Set ROOT, JOURNAL_NAME, JOURNAL and LESSONS for a project root. Projects made
# with the earlier project kit keep their design-journal/ folder, which they
# commit to git on purpose, and their training manual in place of lessons.md.
set_project() {
  ROOT="$1"
  migrate_project_journal "$ROOT"
  if [ -d "$ROOT/design-journal" ] && [ ! -d "$ROOT/.vellum" ]; then
    JOURNAL_NAME="design-journal"
  else
    JOURNAL_NAME=".vellum"
  fi
  JOURNAL="$ROOT/$JOURNAL_NAME"
  if [ -f "$JOURNAL/training-manual.md" ] && [ ! -f "$JOURNAL/lessons.md" ]; then
    LESSONS="training-manual.md"
  else
    LESSONS="lessons.md"
  fi
}

# Keep the journal out of git without touching the shared .gitignore.
git_exclude_file() {
  local root="$1" common
  command -v git >/dev/null 2>&1 || return 1
  common=$(cd "$root" && git rev-parse --git-common-dir 2>/dev/null) || return 1
  case "$common" in /*) ;; *) common="$root/$common" ;; esac
  echo "$common/info/exclude"
}

add_git_exclude() {
  local exclude
  [ "$JOURNAL_NAME" = ".vellum" ] || return 0
  exclude=$(git_exclude_file "$1") || return 0
  mkdir -p "$(dirname "$exclude")"
  if [ ! -f "$exclude" ] || ! grep -qxF "/$JOURNAL_NAME/" "$exclude"; then
    if [ -s "$exclude" ] && [ -n "$(tail -c1 "$exclude")" ]; then echo >>"$exclude"; fi
    echo "/$JOURNAL_NAME/" >>"$exclude"
  fi
}

remove_git_exclude() {
  local exclude
  [ "$JOURNAL_NAME" = ".vellum" ] || return 0
  exclude=$(git_exclude_file "$1") || return 0
  [ -f "$exclude" ] || return 0
  grep -vxF "/$JOURNAL_NAME/" "$exclude" >"$exclude.tmp" || true
  mv "$exclude.tmp" "$exclude"
}

# A project set up by the old curl installer: journal/ plus a block in CLAUDE.md.
has_legacy_journal() {
  local root="$1"
  [ -d "$root/journal" ] && [ -f "$root/CLAUDE.md" ] && grep -q "scribe-block-begin" "$root/CLAUDE.md"
}

# The old curl installer wired its hooks into ~/.claude/settings.json.
has_legacy_install() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  [ -f "$settings" ] && grep -q '\.scribe/hooks/' "$settings"
}

require_journal() {
  set_project "$(project_root)"
  if [ ! -d "$JOURNAL" ]; then
    if has_legacy_journal "$ROOT"; then
      die "this project uses the old journal/ folder. Run 'vellum migrate' first."
    fi
    die "journaling is not on for this project. Run 'vellum init' to turn it on."
  fi
}

# Sets MODEL_ARGS to the --model flag for helper runs, or to nothing.
set_model_args() {
  local model
  model="$(config_get model default)"
  MODEL_ARGS=()
  [ "$model" = "default" ] || MODEL_ARGS=(--model "$model")
}
