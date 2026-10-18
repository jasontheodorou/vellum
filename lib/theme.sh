#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# The Vellum look for Apple's Terminal: the Paper Mono font and the Vellum
# profile, made the default for new windows. `vellum theme undo` puts the
# previous default back.

THEME_DIR="$PLUGIN_ROOT/theme"
THEME_NAME="Vellum"
THEME_PREVIOUS="$VELLUM_HOME/theme-previous"

terminal_script() {
  osascript -e "tell application \"Terminal\" to $1" 2>/dev/null
}

has_terminal_profile() {
  [ "$(terminal_script "exists settings set \"$1\"")" = "true" ]
}

# Copy Paper Mono into the user's own fonts folder, which needs no admin rights.
install_fonts() {
  local fonts="$HOME/Library/Fonts" f
  mkdir -p "$fonts"
  for f in "$THEME_DIR"/fonts/*.otf; do
    cmp -s "$f" "$fonts/$(basename "$f")" || cp "$f" "$fonts/"
  done
}

# Opening a .terminal file is the only supported way to add a profile. Terminal
# also opens a window with it, which shows the new look straight away.
import_profile() {
  local _
  has_terminal_profile "$THEME_NAME" && return 0
  open "$THEME_DIR/$THEME_NAME.terminal" || return 1
  for _ in $(seq 1 50); do
    has_terminal_profile "$THEME_NAME" && return 0
    sleep 0.1
  done
  return 1
}

set_default_profile() {
  terminal_script "set default settings to settings set \"$1\"" >/dev/null &&
    terminal_script "set startup settings to settings set \"$1\"" >/dev/null
}

cmd_theme() {
  case "${1:-}" in
    undo) theme_undo; return ;;
    "") ;;
    *) die "unknown option '$1'. Use 'vellum theme' or 'vellum theme undo'." ;;
  esac
  [ "$(uname -s)" = "Darwin" ] || die "the Vellum theme is for Apple's Terminal on macOS"

  install_fonts
  echo "Installed the Paper Mono font."

  local current
  current="$(terminal_script "name of default settings")"
  import_profile || die "Terminal did not add the Vellum profile. Open $THEME_DIR/$THEME_NAME.terminal by hand."
  echo "Added the Vellum profile to Terminal."

  if [ "$current" != "$THEME_NAME" ]; then
    mkdir -p "$VELLUM_HOME"
    [ -n "$current" ] && printf '%s\n' "$current" >"$THEME_PREVIOUS"
  fi
  set_default_profile "$THEME_NAME" || die "could not make Vellum Terminal's default profile"
  current="$(cat "$THEME_PREVIOUS" 2>/dev/null)"
  echo "New Terminal windows now open in Vellum.${current:+ To go back to $current, run '$VELLUM_HOME/bin/vellum theme undo'.}"
}

theme_undo() {
  local previous
  previous="$(cat "$THEME_PREVIOUS" 2>/dev/null)"
  [ -n "$previous" ] || die "there is no earlier Terminal profile to go back to"
  has_terminal_profile "$previous" || die "Terminal no longer has the '$previous' profile"
  set_default_profile "$previous" || die "could not make $previous Terminal's default profile"
  rm -f "$THEME_PREVIOUS"
  echo "New Terminal windows open in $previous again. The Vellum profile and Paper Mono are still installed."
}
