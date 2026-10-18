#!/bin/bash
# Install Vellum: the Terminal look, Claude Code's colours, the journal, and
# the project list with its shapes and ports.
#
#   curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash
#
# Run from a copy of the repository, it installs that copy instead.
# Safe to run again: each step only changes what is not already right.
# Written for bash 3.2+ so it runs on a stock Mac.

set -u

REPO="jasontheodorou/vellum"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
VELLUM_HOME="${VELLUM_HOME:-$HOME/.vellum}"
SETTINGS="$CLAUDE_DIR/settings.json"
SHIM="$VELLUM_HOME/bin/vellum"
# Claude Code's "Light mode (ANSI colours only)": it draws with the Terminal
# profile's 16 colours, which Vellum makes readable on its yellow paper.
CLAUDE_THEME="light-ansi"

say() { printf '%s\n' "$*"; }
fail() { printf '\nVellum was not installed: %s\n' "$*" >&2; exit 1; }
step() { printf '  %s\n' "$*"; }

[ "$(uname -s)" = "Darwin" ] || fail "Vellum is for macOS only."
command -v claude >/dev/null 2>&1 ||
  fail "Claude Code is not installed. Install it from https://claude.com/claude-code, then run this again."
[ -x /usr/bin/python3 ] || fail "macOS's python3 is missing. Run 'xcode-select --install', then run this again."

if [ -f "$SETTINGS" ] && ! /usr/bin/python3 -I -c 'import json, sys; json.load(open(sys.argv[1]))' "$SETTINGS" 2>/dev/null; then
  fail "Claude Code's settings file $SETTINGS is not valid JSON. Fix it, then run this again."
fi

# A local copy of the repository, when this script is run from one.
source_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$here/.claude-plugin/marketplace.json" ] && source_dir="$here"
fi

say "Installing Vellum..."

# 1. The plugin: the journal, the project list, shapes and ports. Scribe was
#    Vellum's earlier name, so its plugin goes, keeping its data for Vellum.
if claude plugin list --json 2>/dev/null | grep -q '"scribe@'; then
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
step "Installed the Claude Code plugin, version $("$latest" version)."

# 2. A fixed path to the plugin, for the status line and for `vellum theme undo`.
#    A small helper finds the newest copy of the plugin each time.
mkdir -p "$(dirname "$SHIM")"
cat >"$SHIM" <<EOF
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
  "$SHIM" remove-old-install >/dev/null && step "Removed the old curl-installed Scribe. Archived projects were kept."
fi

# 4. The Terminal look: Paper Mono and the Vellum profile, made the default.
theme_out="$("$SHIM" theme 2>&1)" || fail "the Terminal profile could not be set up. $theme_out"
step "Vellum is Terminal's default profile, with the Paper Mono font."

# 5. Claude Code's settings: colours from the Terminal profile, and the status
#    line. A status line of the person's own is left alone.
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.before-vellum"
mkdir -p "$CLAUDE_DIR"
settings_out="$(/usr/bin/python3 -I - "$SETTINGS" "$SHIM statusline" "$CLAUDE_THEME" <<'PY'
import json, os, sys
path, command, theme = sys.argv[1:4]
try:
    data = json.load(open(path)) if os.path.exists(path) else {}
except ValueError:
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
print(" ".join(done))
PY
)"
case "$settings_out" in
  unreadable) fail "Claude Code's settings file $SETTINGS is not valid JSON. Fix it, then run this again." ;;
esac
step "Claude Code uses the Terminal's colours (Light mode, ANSI colours only)."
case " $settings_out " in
  *" own-statusline "*) own_statusline=1 ;;
  *) own_statusline=""; step "The status line shows each project's shape, name and live port." ;;
esac

# Welcome.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  ink=$'\033[1m' berry=$'\033[35m' blue=$'\033[34m' dim=$'\033[90m' off=$'\033[0m'
else
  ink="" berry="" blue="" dim="" off=""
fi
cat <<EOF

${berry}  __     __   _ _
  \\ \\   / /__| | |_   _ _ __ ___
   \\ \\ / / _ \\ | | | | | '_ \` _ \\
    \\ V /  __/ | | |_| | | | | | |
     \\_/ \\___|_|_|\\__,_|_| |_| |_|${off}

  ${ink}Welcome to Vellum.${off} Your Terminal, journal and projects are ready.

  ${blue}●${off} ${ink}Talk, do not type commands.${off} Say what you want in plain English.
  ${blue}●${off} ${ink}Every project keeps a journal${off} of decisions, lessons and what is next.
  ${blue}●${off} ${ink}Every project has its own shape and port${off}, so windows and servers never clash.

  ${ink}Next${off}
    1. Switch to the new Vellum window that just opened.
    2. Type ${ink}claude${off} and press Enter.
    3. Say "start a new project called garden planner" or "what projects do I have?"

EOF
pgrep -qx claude 2>/dev/null &&
  say "  Claude Code is already running somewhere. Restart it to pick up the new colours." && say ""
[ -n "$own_statusline" ] && {
  say "  ${dim}You already had a status line, so it was left alone. To use Vellum's, set its command to:${off}"
  say "  ${dim}$SHIM statusline${off}"
  say ""
}
say "  ${dim}To go back to your old Terminal look: $SHIM theme undo${off}"
say "  ${dim}Your previous Claude Code settings are saved in $SETTINGS.before-vellum${off}"
say ""
