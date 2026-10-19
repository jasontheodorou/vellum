#!/bin/bash
# Install Vellum: the Terminal look, Claude Code's colours, the journal, and
# the project list with its shapes and ports.
#
#   curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash
#
# Run from a copy of the repository, it installs that copy instead.
# Safe to run again: each step only changes what is not already right.
# Written for bash 3.2+ so it runs on a stock Mac.
#
# Everything is inside main, which is called on the last line. When the script
# is piped into bash, bash reads it as it downloads, so nothing runs until the
# whole file has arrived, and a command that reads standard input cannot
# swallow the rest of the script.

set -u

REPO="jasontheodorou/vellum"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
VELLUM_HOME="${VELLUM_HOME:-$HOME/.vellum}"
SETTINGS="$CLAUDE_DIR/settings.json"
BACKUP="$SETTINGS.before-vellum"
SHIM="$VELLUM_HOME/bin/vellum"
# Claude Code's "Light mode (ANSI colours only)": it draws with the Terminal
# profile's 16 colours, which Vellum makes readable on its yellow paper.
CLAUDE_THEME="light-ansi"
# The oldest Claude Code that Vellum is tested with.
MIN_CLAUDE="2.1.292"

say() { printf '%s\n' "$*"; }
fail() { printf '\nVellum was not installed: %s\n' "$*" >&2; exit 1; }
step() { printf '  %s\n' "$*"; }

# True when version $1 is $2 or later. Both are dotted numbers.
version_at_least() {
  local IFS=. i
  # shellcheck disable=SC2206 # splitting on dots is the point
  local a=($1) b=($2)
  for i in 0 1 2 3; do
    [ "${a[i]:-0}" -gt "${b[i]:-0}" ] && return 0
    [ "${a[i]:-0}" -lt "${b[i]:-0}" ] && return 1
  done
  return 0
}

check_requirements() {
  local version
  [ "$(uname -s)" = "Darwin" ] || fail "Vellum is for macOS only."
  command -v claude >/dev/null 2>&1 ||
    fail "Claude Code is not installed. Install it from https://claude.com/claude-code, then run this again."
  version="$(claude --version </dev/null 2>/dev/null | sed -n '1s/^\([0-9][0-9.]*\).*/\1/p')"
  if [ -n "$version" ] && ! version_at_least "$version" "$MIN_CLAUDE"; then
    fail "Vellum needs Claude Code $MIN_CLAUDE or later, and you have $version. Run 'claude update', then run this again."
  fi
  # Without the Command Line Tools, /usr/bin/python3 and git exist but only
  # offer to install them, so try running each one.
  if ! /usr/bin/python3 -c '' </dev/null >/dev/null 2>&1 || ! git --version </dev/null >/dev/null 2>&1; then
    fail "Vellum needs Apple's Command Line Tools. Run 'xcode-select --install', wait for it to finish, then run this again."
  fi
  if [ -f "$SETTINGS" ] && ! /usr/bin/python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$SETTINGS" </dev/null 2>/dev/null; then
    fail "Claude Code's settings file $SETTINGS is not valid JSON. Fix it, then run this again."
  fi
}

# Keep Claude Code's settings as they were before Vellum first touched them.
# A later run never replaces this copy. With no settings file yet, the copy is
# an empty one, so a rerun does not mistake Vellum's settings for the person's.
back_up_settings() {
  [ -e "$BACKUP" ] && return 0
  mkdir -p "$CLAUDE_DIR" || fail "could not create $CLAUDE_DIR."
  if [ -f "$SETTINGS" ]; then
    cp "$SETTINGS" "$BACKUP" || fail "could not back up $SETTINGS."
  else
    printf '{}\n' >"$BACKUP" || fail "could not write $BACKUP."
  fi
}

# Claude Code's settings: colours from the Terminal profile, and the status
# line. A status line of the person's own is left alone. Prints what changed.
update_settings() {
  /usr/bin/python3 -I - "$SETTINGS" "$SHIM statusline" "$CLAUDE_THEME" <<'PY'
import json, os, sys
path, command, theme = sys.argv[1:4]
try:
    data = json.load(open(path)) if os.path.exists(path) else {}
except ValueError:
    print("unreadable")
    sys.exit(0)
if not isinstance(data, dict):
    print("unreadable")
    sys.exit(0)
done = []
if data.get("theme") != theme:
    data["theme"] = theme
    done.append("theme")
current = (data.get("statusLine") or {}).get("command", "")
if current == command:
    pass
elif current == "" or current.endswith(("/scribe statusline", "/vellum statusline", " scribe statusline")):
    data["statusLine"] = {"type": "command", "command": command}
    done.append("statusline")
else:
    done.append("own-statusline")
if set(done) - {"own-statusline"}:
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)
print("ok " + " ".join(done))
PY
}

main() {
  local source_dir="" here latest f theme_out settings_out own_statusline="" dim="" off="" window

  check_requirements

  # A local copy of the repository, when this script is run from one.
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    [ -f "$here/.claude-plugin/marketplace.json" ] && source_dir="$here"
  fi

  say "Installing Vellum..."

  # Before anything changes settings.json: `claude plugin install` adds the
  # marketplace and the plugin to it.
  back_up_settings

  # 1. The plugin: the journal, the project list, shapes and ports. Scribe was
  #    Vellum's earlier name, so its plugin goes, keeping its data for Vellum.
  if claude plugin list --json </dev/null 2>/dev/null | grep -q '"scribe@'; then
    claude plugin uninstall scribe --keep-data </dev/null >/dev/null 2>&1 &&
      step "Removed the Scribe plugin. Vellum takes over its projects and journals."
  fi
  claude plugin install vellum --marketplace "${source_dir:-$REPO}" </dev/null >/dev/null 2>&1 ||
    fail "Claude Code could not install the plugin. Run 'claude plugin install vellum --marketplace ${source_dir:-$REPO}' to see why."

  # The newest installed copy. Its folder name changes with each version.
  latest=""
  for f in "$CLAUDE_DIR"/plugins/cache/*/vellum/*/bin/vellum; do
    [ -x "$f" ] || continue
    if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then latest="$f"; fi
  done
  [ -n "$latest" ] || fail "the plugin installed, but its files were not found in $CLAUDE_DIR/plugins/cache."
  step "Installed the Claude Code plugin, version $("$latest" version </dev/null)."

  # 2. A fixed path to the plugin, for the status line and for `vellum theme undo`.
  #    A small helper finds the newest copy of the plugin each time.
  mkdir -p "$(dirname "$SHIM")" || fail "could not create $(dirname "$SHIM")."
  cat >"$SHIM" <<EOF || fail "could not write $SHIM."
#!/bin/bash
# Runs the newest installed copy of the Vellum plugin. Written by install.sh.
latest=""
for f in "$CLAUDE_DIR"/plugins/cache/*/vellum/*/bin/vellum; do
  [ -x "\$f" ] || continue
  if [ -z "\$latest" ] || [ "\$f" -nt "\$latest" ]; then latest="\$f"; fi
done
[ -n "\$latest" ] || exit 0
exec "\$latest" "\$@"
EOF
  chmod +x "$SHIM"

  # 3. The old curl-installed Scribe, if it is still wired in. Archived projects
  #    are kept, and settings.json is backed up first.
  if [ -f "$SETTINGS" ] && grep -q '\.scribe/hooks/' "$SETTINGS"; then
    "$SHIM" remove-old-install </dev/null >/dev/null &&
      step "Removed the old curl-installed Scribe. Archived projects were kept."
  fi

  # 4. The Terminal look: Paper Mono and the Vellum profile, made the default.
  theme_out="$("$SHIM" theme </dev/null 2>&1)" || fail "the Terminal profile could not be set up. $theme_out"
  step "Vellum is Terminal's default profile, with the Paper Mono font."

  # 5. Claude Code's colours and the status line.
  settings_out="$(update_settings)" ||
    fail "Claude Code's settings file $SETTINGS could not be updated. Check you can write to it, then run this again."
  case "$settings_out" in
    unreadable) fail "Claude Code's settings file $SETTINGS is not valid JSON. Fix it, then run this again." ;;
    "ok"*) ;;
    *) fail "Claude Code's settings file $SETTINGS could not be updated. Check you can write to it, then run this again." ;;
  esac
  step "Claude Code uses the Terminal's colours (Light mode, ANSI colours only)."
  case " $settings_out " in
    *" own-statusline "*) own_statusline=1 ;;
    *) step "The status line shows each project's shape, name and live port." ;;
  esac

  # Welcome: in the new Vellum window if Terminal opened one, so it shows in
  # Vellum's own colours, otherwise here.
  if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then dim=$'\033[90m' off=$'\033[0m'; fi
  window="$(cat "$VELLUM_HOME/theme-window" 2>/dev/null)"
  rm -f "$VELLUM_HOME/theme-window"
  if [ -n "$window" ] &&
    osascript -e "tell application \"Terminal\" to do script \"clear; '$SHIM' welcome\" in tab 1 of window id $window" \
      -e "tell application \"Terminal\" to set index of window id $window to 1" </dev/null >/dev/null 2>&1; then
    say ""
    say "Vellum is installed. Carry on in the new yellow Vellum window."
  else
    "$SHIM" welcome </dev/null
  fi
  say ""
  if pgrep -qx claude 2>/dev/null; then
    say "  Claude Code is already running somewhere. Restart it to pick up the new colours."
    say ""
  fi
  if [ -n "$own_statusline" ]; then
    say "  ${dim}You already had a status line, so it was left alone. To use Vellum's, set its command to:${off}"
    say "  ${dim}$SHIM statusline${off}"
    say ""
  fi
  # The empty copy stands for "no settings before Vellum", so say nothing then.
  if [ -s "$BACKUP" ] && [ "$(cat "$BACKUP")" != "{}" ]; then
    say "  ${dim}Your previous Claude Code settings are saved in $BACKUP${off}"
    say ""
  fi
}

main "$@"
