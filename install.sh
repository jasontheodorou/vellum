#!/bin/bash
# Install Vellum: the Terminal look, the journal, and the project list with
# its shapes and ports.
#
#   curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash
#
# Run from a copy of the repository, it installs that copy instead.
# Written for bash 3.2+ so it runs on a stock Mac.

set -u

REPO="jasontheodorou/vellum"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
VELLUM_HOME="${VELLUM_HOME:-$HOME/.vellum}"
SETTINGS="$CLAUDE_DIR/settings.json"
SHIM="$VELLUM_HOME/bin/vellum"

say() { printf '%s\n' "$*"; }
fail() { printf 'Vellum was not installed: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = "Darwin" ] || fail "Vellum is for macOS only."
command -v claude >/dev/null 2>&1 ||
  fail "Claude Code is not installed. Install it from https://claude.com/claude-code, then run this again."

# A local copy of the repository, when this script is run from one.
source_dir=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  [ -f "$here/.claude-plugin/marketplace.json" ] && source_dir="$here"
fi

# 1. The plugin: the journal, the project list, shapes and ports.
say "Installing the Vellum plugin for Claude Code..."
claude plugin install vellum --marketplace "${source_dir:-$REPO}" </dev/null ||
  fail "Claude Code could not install the plugin."

# The newest installed copy. Its folder name changes with each version.
latest=""
for f in "$CLAUDE_DIR"/plugins/cache/*/vellum/*/bin/vellum; do
  [ -x "$f" ] || continue
  if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then latest="$f"; fi
done
[ -n "$latest" ] || fail "the plugin installed, but its files were not found in $CLAUDE_DIR/plugins/cache."

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

# 3. The Terminal look: Paper Mono and the Vellum profile, made the default.
"$latest" theme || fail "the Terminal profile could not be set up."

# 4. The status line.
status_command="$SHIM statusline"
current=""
[ -f "$SETTINGS" ] && current="$(/usr/bin/python3 -I -c '
import json, sys
try:
    print(json.load(open(sys.argv[1])).get("statusLine", {}).get("command", ""))
except Exception:
    print("?")' "$SETTINGS")"

case "$current" in
  "$status_command") ;;
  ""|*/scribe\ statusline|*/vellum\ statusline)
    mkdir -p "$CLAUDE_DIR"
    [ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.before-vellum"
    /usr/bin/python3 -I -c '
import json, os, sys
path, command = sys.argv[1], sys.argv[2]
data = json.load(open(path)) if os.path.exists(path) else {}
data["statusLine"] = {"type": "command", "command": command}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")' "$SETTINGS" "$status_command" ||
      fail "could not turn on the status line in $SETTINGS."
    say "Turned on the Vellum status line."
    ;;
  "?")
    say "Your Claude Code settings file could not be read, so the status line was left off."
    say "To turn it on, add this to $SETTINGS:"
    say "  \"statusLine\": {\"type\": \"command\", \"command\": \"$status_command\"}"
    ;;
  *)
    say "You already have a status line, so it was left alone. To use Vellum's instead, set its command to:"
    say "  $status_command"
    ;;
esac

say ""
say "Vellum is installed. Use the new Vellum window, type claude, and say what you want to work on."
