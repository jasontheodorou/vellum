#!/bin/bash
# Sourced by bin/scribe. Written for bash 3.2+.
# shellcheck shell=bash

# Shared helpers, settings and per-project state.

# Set while a background helper runs, so its own session does not start another.
# CLAUDE_JOURNAL_HOOK is the name the pre-plugin version used.
is_helper_session() {
  [ "${SCRIBE_SUBAGENT:-0}" = "1" ] || [ "${CLAUDE_JOURNAL_HOOK:-0}" = "1" ]
}

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

log() {
  mkdir -p "$SCRIBE_HOME" 2>/dev/null || return 0
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$GLOBAL_LOG" 2>/dev/null || true
}

die() { echo "scribe: $*" >&2; exit 1; }

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
project_root() {
  local dir="${1:-$PWD}" up
  if command -v git >/dev/null 2>&1; then
    up=$(cd "$dir" 2>/dev/null && git rev-parse --show-cdup 2>/dev/null) && {
      (cd "$dir/$up" 2>/dev/null && pwd -P) && return 0
    }
  fi
  (cd "$dir" 2>/dev/null && pwd -P) || echo "$dir"
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
  if [ -n "${SCRIBE_DESKTOP:-}" ]; then
    mkdir -p "$SCRIBE_DESKTOP" && echo "$SCRIBE_DESKTOP"
    return 0
  fi
  if [ -d "$HOME/Desktop" ]; then
    echo "$HOME/Desktop"
    return 0
  fi
  echo "$HOME"
  echo "scribe: could not find a Desktop folder, so using your home folder" >&2
}

# ---------------------------------------------------------------------------
# Settings (~/.scribe/config, one key=value per line)
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
  mkdir -p "$SCRIBE_HOME"
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
      mkdir -p "$value" || die "could not create $value"
      config_set projects-dir "$(cd "$value" && pwd)"
      echo "New projects will go in $(cd "$value" && pwd)."
      ;;
    *) die "unknown setting '$key' (settings: background, model, projects-dir)" ;;
  esac
}

# ---------------------------------------------------------------------------
# Per-project state
# ---------------------------------------------------------------------------

is_declined() {
  local root="$1"
  [ -f "$root/.scribe-declined" ] && return 0
  [ -f "$DECLINED" ] && grep -qxF "$root" "$DECLINED"
}

# Set ROOT, JOURNAL_NAME, JOURNAL and LESSONS for a project root. Projects made
# with the earlier project kit keep their design-journal/ folder, which they
# commit to git on purpose, and their training manual in place of lessons.md.
set_project() {
  ROOT="$1"
  if [ -d "$ROOT/design-journal" ] && [ ! -d "$ROOT/.scribe" ]; then
    JOURNAL_NAME="design-journal"
  else
    JOURNAL_NAME=".scribe"
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
  [ "$JOURNAL_NAME" = ".scribe" ] || return 0
  exclude=$(git_exclude_file "$1") || return 0
  mkdir -p "$(dirname "$exclude")"
  if [ ! -f "$exclude" ] || ! grep -qxF "/$JOURNAL_NAME/" "$exclude"; then
    if [ -s "$exclude" ] && [ -n "$(tail -c1 "$exclude")" ]; then echo >>"$exclude"; fi
    echo "/$JOURNAL_NAME/" >>"$exclude"
  fi
}

remove_git_exclude() {
  local exclude
  [ "$JOURNAL_NAME" = ".scribe" ] || return 0
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
  [ -f "$HOME/.claude/settings.json" ] && grep -q '\.scribe/hooks/' "$HOME/.claude/settings.json"
}

require_journal() {
  set_project "$(project_root)"
  if [ ! -d "$JOURNAL" ]; then
    if has_legacy_journal "$ROOT"; then
      die "this project uses the old journal/ folder. Run 'scribe migrate' first."
    fi
    die "journaling is not on for this project. Run 'scribe init' to turn it on."
  fi
}

# Sets MODEL_ARGS to the --model flag for helper runs, or to nothing.
set_model_args() {
  local model
  model="$(config_get model default)"
  MODEL_ARGS=()
  [ "$model" = "default" ] || MODEL_ARGS=(--model "$model")
}
