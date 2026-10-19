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
# The window Terminal opened when the profile was first added.
THEME_WINDOW="$VELLUM_HOME/theme-window"

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

# Terminal reads the font when it adds the profile. A font copied a moment
# earlier is often not registered yet, so Terminal falls back to the system
# font at 11pt. Set the font again once Terminal can see it.
PROFILE_FONT="PaperMono-Regular"
PROFILE_FONT_SIZE=18

profile_font() {
  terminal_script "(font name of settings set \"$THEME_NAME\") & \" \" & (font size of settings set \"$THEME_NAME\")"
}

fix_profile_font() {
  local _
  for _ in $(seq 1 50); do
    terminal_script "set font name of settings set \"$THEME_NAME\" to \"$PROFILE_FONT\"" >/dev/null
    terminal_script "set font size of settings set \"$THEME_NAME\" to $PROFILE_FONT_SIZE" >/dev/null
    [ "$(profile_font)" = "$PROFILE_FONT $PROFILE_FONT_SIZE" ] && return 0
    sleep 0.1
  done
  return 1
}

window_ids() {
  terminal_script "id of every window" | tr ',' '\n' | tr -d ' '
}

# Opening a .terminal file is the only supported way to add a profile. Terminal
# also opens a window with it. Pass "close" to close that window again;
# otherwise its id is kept in THEME_WINDOW, so the installer can greet the
# person there.
import_profile() {
  local before _ id
  before="$(window_ids)"
  open "$THEME_FILE" || return 1
  for _ in $(seq 1 50); do
    has_terminal_profile "$THEME_NAME" && break
    sleep 0.1
  done
  has_terminal_profile "$THEME_NAME" || return 1
  # The window can appear a moment after the profile does.
  for _ in $(seq 1 30); do
    for id in $(window_ids); do
      printf '%s\n' "$before" | grep -qxF "$id" && continue
      if [ "${1:-}" = "close" ]; then
        terminal_script "close window id $id" >/dev/null
      else
        mkdir -p "$VELLUM_HOME" && echo "$id" >"$THEME_WINDOW"
      fi
      return 0
    done
    sleep 0.1
  done
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
  fix_profile_font || die "Terminal did not take the Paper Mono font. Restart Terminal, then run 'vellum theme' again."
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
  local previous terminal_done="" claude_out="" claude_done=""
  previous="$(cat "$THEME_PREVIOUS" 2>/dev/null)"
  if [ -n "$previous" ]; then
    has_terminal_profile "$previous" || die "Terminal no longer has the '$previous' profile"
    set_default_profile "$previous" || die "could not make $previous Terminal's default profile"
    rm -f "$THEME_PREVIOUS"
    terminal_done=1
    echo "New Terminal windows open in $previous again. The Vellum profile and Paper Mono are still installed."
  fi
  claude_out="$(claude_theme_undo)" && claude_done=1
  if [ -z "$terminal_done" ] && [ -z "$claude_done" ]; then
    [ -n "$claude_out" ] && printf '%s\n' "$claude_out" >&2
    die "there is no earlier Terminal profile to go back to"
  fi
  [ -n "$terminal_done" ] || echo "There is no earlier Terminal profile to go back to, so Terminal was left alone."
  [ -n "$claude_out" ] && printf '%s\n' "$claude_out"
  return 0
}

# Put Claude Code's theme back to what it was before the installer set it,
# using the copy of settings.json the installer kept. Prints what it did, and
# fails when the theme was not changed (the installer never ran, the theme was
# already changed, or it could not be).
claude_theme_undo() {
  local settings="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
  local backup="$settings.before-vellum"
  [ -f "$backup" ] && [ -f "$settings" ] || return 1
  if ! /usr/bin/python3 -c '' </dev/null >/dev/null 2>&1; then
    echo "Claude Code's theme was not changed back, because macOS's python3 is not available. To change it yourself, type /config in Claude Code and choose a theme."
    return 1
  fi
  /usr/bin/python3 -I - "$settings" "$backup" <<'PY'
import json, os, sys
path, backup = sys.argv[1:3]
VELLUM_THEME = "light-ansi"
try:
    data = json.load(open(path))
    before = json.load(open(backup))
    assert isinstance(data, dict) and isinstance(before, dict)
except (ValueError, AssertionError, OSError):
    print("Claude Code's theme was not changed back, because a settings file could not be read. To change it yourself, type /config in Claude Code and choose a theme.")
    sys.exit(1)
changed = False
if data.get("theme") != VELLUM_THEME:
    print("Claude Code's theme is no longer Vellum's, so it was left alone.")
elif before.get("theme") == VELLUM_THEME:
    print("Claude Code's theme was already Light mode (ANSI colours only) before Vellum, so it was left alone.")
else:
    if "theme" in before:
        data["theme"] = before["theme"]
        said = "Claude Code's theme is back to \"%s\"." % before["theme"]
    else:
        data.pop("theme", None)
        said = "Claude Code's theme is back to its default."
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    changed = True
    print(said + " Restart Claude Code to see it.")
# The installer turned off Claude Code's own recap when it had no setting.
if "awaySummaryEnabled" not in before and data.get("awaySummaryEnabled") is False:
    data.pop("awaySummaryEnabled")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
    changed = True
    print("Claude Code's own recap after five minutes away is back on.")
if str((data.get("statusLine") or {}).get("command", "")).endswith("vellum statusline"):
    print("Vellum's status line is still on. To remove it, delete the \"statusLine\" entry from %s." % path)
sys.exit(0 if changed else 1)
PY
}

# The welcome screen, shown once by the installer in the new Vellum window.
cmd_welcome() {
  local ink="" blue="" dim="" off=""
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    ink=$'\033[1m' blue=$'\033[34m' dim=$'\033[90m' off=$'\033[0m'
  fi
  cat <<EOF

${blue}  ██╗   ██╗███████╗██╗     ██╗     ██╗   ██╗███╗   ███╗
  ██║   ██║██╔════╝██║     ██║     ██║   ██║████╗ ████║
  ██║   ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║
  ╚██╗ ██╔╝██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║
   ╚████╔╝ ███████╗███████╗███████╗╚██████╔╝██║ ╚═╝ ██║
    ╚═══╝  ╚══════╝╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝${off}

  ${ink}Welcome to Vellum.${off} Your Terminal, journal and projects are ready.

  ${blue}●${off} ${ink}Talk, do not type commands.${off} Say what you want in plain English.
  ${blue}●${off} ${ink}Every project keeps a journal${off} of decisions, lessons and what is next.
  ${blue}●${off} ${ink}Every project has its own shape and port${off}, so windows and servers never clash.

  ${ink}Start${off}
    Type ${ink}claude${off} and press Enter, then say
    "start a new project called garden planner" or "what projects do I have?"

  ${dim}To go back to your old Terminal look: $VELLUM_HOME/bin/vellum theme undo${off}

EOF
}
