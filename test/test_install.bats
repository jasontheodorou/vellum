#!/usr/bin/env bats
# install.sh, with fake claude, osascript and open standing in for the real ones.

load helpers

setup() {
  setup_isolated_env
  export CLAUDE_CONFIG_DIR="$HOME/.claude"
  mkdir -p "$CLAUDE_CONFIG_DIR"
  TERMINAL="$TEST_HOME/terminal"
  mkdir -p "$TERMINAL"
  echo "Man Page" > "$TERMINAL/default"
  echo "Man Page" > "$TERMINAL/profiles"
  export TERMINAL

  # claude: "plugin install" copies this repository into the plugin cache.
  cat > "$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
echo "$*" >> "$TEST_HOME/claude.args"
case "$1 ${2:-}" in
  "--version ") echo "${FAKE_CLAUDE_VERSION:-2.1.303} (Claude Code)" ;;
  "plugin list") cat "$TEST_HOME/plugins.json" 2>/dev/null || echo "[]" ;;
  "plugin install")
    dest="$CLAUDE_CONFIG_DIR/plugins/cache/vellum/vellum/0.10.0"
    mkdir -p "$dest" && cp -R "$VELLUM_REPO"/bin "$VELLUM_REPO"/lib "$VELLUM_REPO"/templates \
      "$VELLUM_REPO"/theme "$VELLUM_REPO"/.claude-plugin "$dest"/
    # Like the real one, it records the plugin in settings.json.
    /usr/bin/python3 -I -c 'import json, os, sys
p = sys.argv[1]
d = json.load(open(p)) if os.path.exists(p) else {}
d["enabledPlugins"] = {"vellum@vellum": True}
f = open(p, "w"); json.dump(d, f, indent=2); f.write("\n")' "$CLAUDE_CONFIG_DIR/settings.json"
    [ -z "${FAKE_LOCK_SETTINGS:-}" ] || chmod a-w "$CLAUDE_CONFIG_DIR" ;;
  "plugin uninstall") echo "$3" >> "$TEST_HOME/uninstalled" ;;
esac
FAKE
  cat > "$FAKEBIN/osascript" <<'FAKE'
#!/bin/bash
[ "${1:-}" = "-e" ] || { cat >/dev/null; exit 0; }
script="$2"
name="${script#*settings set \"}"; name="${name%\"}"
case "$script" in
  *"set font name of settings set"*) echo "${script##* to \"}" | tr -d '"' > "$TERMINAL/font_name" ;;
  *"set font size of settings set"*) echo "${script##* to }" > "$TERMINAL/font_size" ;;
  *"to (font name of"*) echo "$(cat "$TERMINAL/font_name" 2>/dev/null || echo .AppleSystemUIFont) $(cat "$TERMINAL/font_size" 2>/dev/null || echo 11)" ;;
  *"name of default settings"*) cat "$TERMINAL/default" ;;
  *"exists settings set"*) grep -qxF "$name" "$TERMINAL/profiles" && echo true || echo false ;;
  *"set default settings to"*) echo "$name" > "$TERMINAL/default" ;;
  *"set startup settings to"*) echo "$name" > "$TERMINAL/startup" ;;
  *"id of every window"*) cat "$TERMINAL/windows" 2>/dev/null ;;
  *"do script"*) echo "$script" >> "$TERMINAL/scripts" ;;
esac
FAKE
  cat > "$FAKEBIN/open" <<'FAKE'
#!/bin/bash
basename "$1" .terminal >> "$TERMINAL/profiles"
echo 42 >> "$TERMINAL/windows"
FAKE
  chmod +x "$FAKEBIN/claude" "$FAKEBIN/osascript" "$FAKEBIN/open"
  export VELLUM_REPO
}
teardown() {
  chmod u+w "$CLAUDE_CONFIG_DIR" 2>/dev/null
  teardown_isolated_env
}

settings() { cat "$CLAUDE_CONFIG_DIR/settings.json"; }

@test "install: a fresh Mac gets the plugin, theme, Claude colours and status line" {
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -eq 0 ]
  grep -q "plugin install vellum --marketplace $VELLUM_REPO" "$TEST_HOME/claude.args"
  grep -qx Vellum "$TERMINAL/default"
  [ -f "$HOME/Library/Fonts/PaperMono-Regular.otf" ]
  settings | grep -q '"theme": "custom:vellum"'
  settings | grep -q "\"command\": \"$HOME/.vellum/bin/vellum statusline\""
  [ -x "$HOME/.vellum/bin/vellum" ]
}

@test "install: the helper runs the installed plugin" {
  bash "$VELLUM_REPO/install.sh"
  run "$HOME/.vellum/bin/vellum" version
  [ "$output" = "0.10.0" ]
}

@test "install: keeps other settings and backs them up" {
  echo '{"model": "opus", "theme": "dark"}' > "$CLAUDE_CONFIG_DIR/settings.json"
  run bash "$VELLUM_REPO/install.sh"
  settings | grep -q '"model": "opus"'
  settings | grep -q '"theme": "custom:vellum"'
  grep -q '"theme": "dark"' "$CLAUDE_CONFIG_DIR/settings.json.before-vellum"
  [[ "$output" == *"previous Claude Code settings are saved in"* ]] || false
}

@test "install: the backup is taken before the plugin changes settings.json" {
  echo '{"theme": "dark"}' > "$CLAUDE_CONFIG_DIR/settings.json"
  bash "$VELLUM_REPO/install.sh"
  settings | grep -q enabledPlugins
  refute grep -q enabledPlugins "$CLAUDE_CONFIG_DIR/settings.json.before-vellum"
}

@test "install: running it again keeps the first backup" {
  echo '{"theme": "dark"}' > "$CLAUDE_CONFIG_DIR/settings.json"
  bash "$VELLUM_REPO/install.sh"
  bash "$VELLUM_REPO/install.sh"
  grep -q '"theme": "dark"' "$CLAUDE_CONFIG_DIR/settings.json.before-vellum"
  refute grep -q custom:vellum "$CLAUDE_CONFIG_DIR/settings.json.before-vellum"
}

@test "install: with no settings before, the backup is empty and not mentioned" {
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(cat "$CLAUDE_CONFIG_DIR/settings.json.before-vellum")" = "{}" ]
  [[ "$output" != *"previous Claude Code settings"* ]] || false
  run bash "$VELLUM_REPO/install.sh"
  [ "$(cat "$CLAUDE_CONFIG_DIR/settings.json.before-vellum")" = "{}" ]
}

@test "install: stops when Claude Code is too old" {
  export FAKE_CLAUDE_VERSION=2.1.200
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"needs Claude Code 2.1.292 or later, and you have 2.1.200"* ]] || false
  refute grep -q "plugin install" "$TEST_HOME/claude.args"
}

@test "install: accepts a newer Claude Code with a bigger middle number" {
  export FAKE_CLAUDE_VERSION=2.10.0
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -eq 0 ]
}

@test "install: asks for the Command Line Tools when git is only a stub" {
  printf '#!/bin/bash\necho "xcode-select: note: No developer tools were found" >&2\nexit 1\n' > "$FAKEBIN/git"
  chmod +x "$FAKEBIN/git"
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"xcode-select --install"* ]] || false
  [[ "$output" != *"not valid JSON"* ]] || false
}

@test "install: piped into bash, a command reading stdin cannot swallow the rest" {
  echo '{"theme": "dark"}' > "$CLAUDE_CONFIG_DIR/settings.json"
  # pgrep runs near the end; this one reads everything left on stdin.
  printf '#!/bin/bash\ncat >/dev/null\nexit 1\n' > "$FAKEBIN/pgrep"
  chmod +x "$FAKEBIN/pgrep"
  run bash -c "bash < '$VELLUM_REPO/install.sh'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"previous Claude Code settings are saved in"* ]] || false
  settings | grep -q '"theme": "custom:vellum"'
}

@test "install: does not claim success when settings.json cannot be written" {
  export FAKE_LOCK_SETTINGS=1
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -ne 0 ]
  # The locked folder stops the theme copy before settings.json is reached.
  [[ "$output" == *"could not copy Vellum's Claude Code theme"* ]] || false
  [[ "$output" != *"Vellum is installed"* ]] || false
}

@test "install: replaces Scribe's status line but not someone's own" {
  echo '{"statusLine": {"type": "command", "command": "/x/bin/scribe statusline"}}' > "$CLAUDE_CONFIG_DIR/settings.json"
  bash "$VELLUM_REPO/install.sh"
  settings | grep -q "vellum/bin/vellum statusline"

  echo '{"statusLine": {"type": "command", "command": "my-line"}}' > "$CLAUDE_CONFIG_DIR/settings.json"
  run bash "$VELLUM_REPO/install.sh"
  settings | grep -q '"command": "my-line"'
  [[ "$output" == *"left alone"* ]] || false
}

@test "install: removes the old curl Scribe and the Scribe plugin, keeping their data" {
  mkdir -p "$HOME/.scribe/hooks" "$HOME/.scribe/bin" "$HOME/.scribe/library"
  echo keep > "$HOME/.scribe/library/old.md"
  cat > "$CLAUDE_CONFIG_DIR/settings.json" <<JSON
{"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "$HOME/.scribe/hooks/stop.sh"}]}]}}
JSON
  echo '[{"id": "scribe@scribe"}]' > "$TEST_HOME/plugins.json"
  bash "$VELLUM_REPO/install.sh"
  refute grep -q ".scribe/hooks" "$CLAUDE_CONFIG_DIR/settings.json"
  [ ! -d "$HOME/.scribe" ]
  grep -qx keep "$HOME/.vellum/library/old.md"
  grep -qx scribe "$TEST_HOME/uninstalled"
}

@test "install: running it twice changes nothing more" {
  bash "$VELLUM_REPO/install.sh"
  cp "$CLAUDE_CONFIG_DIR/settings.json" "$TEST_HOME/first.json"
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -eq 0 ]
  cmp "$CLAUDE_CONFIG_DIR/settings.json" "$TEST_HOME/first.json"
  [ "$(grep -cx Vellum "$TERMINAL/profiles")" -eq 1 ]
}

@test "install: stops with a clear message when settings.json is broken" {
  echo '{not json' > "$CLAUDE_CONFIG_DIR/settings.json"
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not valid JSON"* ]] || false
  refute grep -q "plugin install" "$TEST_HOME/claude.args"
}

@test "install: greets the person in the new Vellum window" {
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -eq 0 ]
  grep -q "welcome\" in tab 1 of window id 42" "$TERMINAL/scripts"
  [[ "$output" == *"Carry on in the new yellow Vellum window"* ]] || false
  [ ! -f "$HOME/.vellum/theme-window" ]
}

@test "install: greets here when no new window opened" {
  bash "$VELLUM_REPO/install.sh"
  run bash "$VELLUM_REPO/install.sh"
  [[ "$output" == *"Welcome to Vellum"* ]] || false
}

@test "install: turns off Claude Code's own recap, unless the person chose already" {
  bash "$VELLUM_REPO/install.sh" >/dev/null
  settings | grep -q '"awaySummaryEnabled": false'
}

@test "install: leaves Claude Code's recap setting the person chose" {
  echo '{"awaySummaryEnabled": true}' > "$CLAUDE_CONFIG_DIR/settings.json"
  bash "$VELLUM_REPO/install.sh" >/dev/null
  settings | grep -q '"awaySummaryEnabled": true'
}
