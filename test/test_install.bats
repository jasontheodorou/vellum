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
case "$1 $2" in
  "plugin list") cat "$TEST_HOME/plugins.json" 2>/dev/null || echo "[]" ;;
  "plugin install")
    dest="$CLAUDE_CONFIG_DIR/plugins/cache/vellum/vellum/0.10.0"
    mkdir -p "$dest" && cp -R "$VELLUM_REPO"/bin "$VELLUM_REPO"/lib "$VELLUM_REPO"/templates \
      "$VELLUM_REPO"/theme "$VELLUM_REPO"/.claude-plugin "$dest"/ ;;
  "plugin uninstall") echo "$3" >> "$TEST_HOME/uninstalled" ;;
esac
FAKE
  cat > "$FAKEBIN/osascript" <<'FAKE'
#!/bin/bash
[ "${1:-}" = "-e" ] || { cat >/dev/null; exit 0; }
script="$2"
name="${script#*settings set \"}"; name="${name%\"}"
case "$script" in
  *"name of default settings"*) cat "$TERMINAL/default" ;;
  *"exists settings set"*) grep -qxF "$name" "$TERMINAL/profiles" && echo true || echo false ;;
  *"set default settings to"*) echo "$name" > "$TERMINAL/default" ;;
  *"set startup settings to"*) echo "$name" > "$TERMINAL/startup" ;;
esac
FAKE
  cat > "$FAKEBIN/open" <<'FAKE'
#!/bin/bash
basename "$1" .terminal >> "$TERMINAL/profiles"
FAKE
  chmod +x "$FAKEBIN/claude" "$FAKEBIN/osascript" "$FAKEBIN/open"
  export VELLUM_REPO
}
teardown() { teardown_isolated_env; }

settings() { cat "$CLAUDE_CONFIG_DIR/settings.json"; }

@test "install: a fresh Mac gets the plugin, theme, Claude colours and status line" {
  run bash "$VELLUM_REPO/install.sh"
  [ "$status" -eq 0 ]
  grep -q "plugin install vellum --marketplace $VELLUM_REPO" "$TEST_HOME/claude.args"
  grep -qx Vellum "$TERMINAL/default"
  [ -f "$HOME/Library/Fonts/PaperMono-Regular.otf" ]
  settings | grep -q '"theme": "light-ansi"'
  settings | grep -q "\"command\": \"$HOME/.vellum/bin/vellum statusline\""
  [ -x "$HOME/.vellum/bin/vellum" ]
  [[ "$output" == *"Welcome to Vellum"* ]] || false
}

@test "install: the helper runs the installed plugin" {
  bash "$VELLUM_REPO/install.sh"
  run "$HOME/.vellum/bin/vellum" version
  [ "$output" = "0.10.0" ]
}

@test "install: keeps other settings and backs them up" {
  echo '{"model": "opus", "theme": "dark"}' > "$CLAUDE_CONFIG_DIR/settings.json"
  bash "$VELLUM_REPO/install.sh"
  settings | grep -q '"model": "opus"'
  settings | grep -q '"theme": "light-ansi"'
  grep -q '"theme": "dark"' "$CLAUDE_CONFIG_DIR/settings.json.before-vellum"
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
  [ ! -e "$TEST_HOME/claude.args" ]
}
