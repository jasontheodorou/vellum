#!/bin/bash
# Sourced by bin/vellum. Written for bash 3.2+.
# shellcheck shell=bash

# The Vellum look for Apple's Terminal: the Paper Mono font and the Vellum
# profile, made the default for new windows. `vellum theme undo` puts the
# previous default back.
#
# Terminal never replaces a profile it already has: opening a newer
# Vellum.terminal adds "Vellum 1". So an update deletes the old profile, adds
# the new one, and puts back the default and any windows that were using it.

THEME_DIR="$PLUGIN_ROOT/theme"
THEME_NAME="Vellum"
THEME_FILE="$THEME_DIR/$THEME_NAME.terminal"
THEME_PREVIOUS="$VELLUM_HOME/theme-previous"
# The fingerprint of the profile last added to Terminal, and of an update the
# person said no to.
THEME_INSTALLED="$VELLUM_HOME/theme-installed"
THEME_SKIPPED="$VELLUM_HOME/theme-skipped"

terminal_script() {
  osascript -e "tell application \"Terminal\" to $1" 2>/dev/null
}

has_terminal_profile() {
  [ "$(terminal_script "exists settings set \"$1\"")" = "true" ]
}

theme_fingerprint() {
  shasum -a 256 "$THEME_FILE" | cut -d ' ' -f1
}

# True when the person installed the theme and a newer one has shipped since,
# unless they already said no to this one.
theme_update_waiting() {
  local now
  [ -f "$THEME_INSTALLED" ] || return 1
  now="$(theme_fingerprint)"
  [ "$(cat "$THEME_INSTALLED")" != "$now" ] && [ "$(cat "$THEME_SKIPPED" 2>/dev/null)" != "$now" ]
}

# Copy Paper Mono into the user's own fonts folder, which needs no admin rights.
install_fonts() {
  local fonts="$HOME/Library/Fonts" f
  mkdir -p "$fonts"
  for f in "$THEME_DIR"/fonts/*.otf; do
    cmp -s "$f" "$fonts/$(basename "$f")" || cp "$f" "$fonts/"
  done
}

window_ids() {
  terminal_script "id of every window" | tr ',' '\n' | tr -d ' '
}

# Opening a .terminal file is the only supported way to add a profile. Terminal
# also opens a window with it. Pass "close" to close that window again.
import_profile() {
  local before _ id
  before="$(window_ids)"
  open "$THEME_FILE" || return 1
  for _ in $(seq 1 50); do
    has_terminal_profile "$THEME_NAME" && break
    sleep 0.1
  done
  has_terminal_profile "$THEME_NAME" || return 1
  if [ "${1:-}" = "close" ]; then
    # The window can appear a moment after the profile does.
    for _ in $(seq 1 30); do
      for id in $(window_ids); do
        printf '%s\n' "$before" | grep -qxF "$id" && continue
        terminal_script "close window id $id" >/dev/null
        return 0
      done
      sleep 0.1
    done
  fi
  return 0
}

# Every tab showing the Vellum profile, as "window-id tab-number" lines.
vellum_tabs() {
  osascript 2>/dev/null <<EOF
tell application "Terminal"
  set out to ""
  repeat with w in windows
    repeat with i from 1 to count of tabs of w
      if name of current settings of tab i of w is "$THEME_NAME" then set out to out & (id of w) & " " & i & linefeed
    end repeat
  end repeat
  return out
end tell
EOF
}

replace_profile() {
  local was_default="" was_startup="" tabs wid tab
  [ "$(terminal_script "name of default settings")" = "$THEME_NAME" ] && was_default=1
  [ "$(terminal_script "name of startup settings")" = "$THEME_NAME" ] && was_startup=1
  tabs="$(vellum_tabs)"
  # Lend new windows Basic while Vellum is away.
  [ -n "$was_default" ] && terminal_script "set default settings to settings set \"Basic\"" >/dev/null
  [ -n "$was_startup" ] && terminal_script "set startup settings to settings set \"Basic\"" >/dev/null
  terminal_script "delete settings set \"$THEME_NAME\"" >/dev/null
  import_profile close || return 1
  [ -n "$was_default" ] && terminal_script "set default settings to settings set \"$THEME_NAME\"" >/dev/null
  [ -n "$was_startup" ] && terminal_script "set startup settings to settings set \"$THEME_NAME\"" >/dev/null
  printf '%s\n' "$tabs" | while read -r wid tab; do
    [ -n "$tab" ] || continue
    terminal_script "set current settings of tab $tab of window id $wid to settings set \"$THEME_NAME\"" >/dev/null
  done
  return 0
}

set_default_profile() {
  terminal_script "set default settings to settings set \"$1\"" >/dev/null &&
    terminal_script "set startup settings to settings set \"$1\"" >/dev/null
}

cmd_theme() {
  case "${1:-}" in
    undo) theme_undo; return ;;
    skip) mkdir -p "$VELLUM_HOME"; theme_fingerprint >"$THEME_SKIPPED"; echo "Vellum will not offer this theme update again."; return ;;
    "") ;;
    *) die "unknown option '$1'. Use 'vellum theme', 'vellum theme undo' or 'vellum theme skip'." ;;
  esac
  [ "$(uname -s)" = "Darwin" ] || die "the Vellum theme is for Apple's Terminal on macOS"

  install_fonts
  echo "Installed the Paper Mono font."

  local current
  current="$(terminal_script "name of default settings")"
  if ! has_terminal_profile "$THEME_NAME"; then
    import_profile || die "Terminal did not add the Vellum profile. Open $THEME_FILE by hand."
    echo "Added the Vellum profile to Terminal."
  elif [ "$(cat "$THEME_INSTALLED" 2>/dev/null)" != "$(theme_fingerprint)" ]; then
    replace_profile || die "Terminal did not take the new Vellum profile. Open $THEME_FILE by hand."
    echo "Updated the Vellum profile in Terminal, including windows already open in it."
  fi
  mkdir -p "$VELLUM_HOME"
  theme_fingerprint >"$THEME_INSTALLED"
  rm -f "$THEME_SKIPPED"

  if [ "$current" != "$THEME_NAME" ] && [ -n "$current" ]; then
    printf '%s\n' "$current" >"$THEME_PREVIOUS"
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
