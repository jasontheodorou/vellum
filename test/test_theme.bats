#!/usr/bin/env bats
# The Terminal theme. Fake osascript and open stand in for Terminal.

load helpers

setup() {
  setup_isolated_env
  export CLAUDE_CONFIG_DIR="$HOME/.claude"
  TERMINAL="$TEST_HOME/terminal"
  mkdir -p "$TERMINAL"
  echo "Man Page" > "$TERMINAL/default"
  echo "Man Page" > "$TERMINAL/profiles"
  export TERMINAL
  cat > "$FAKEBIN/osascript" <<'FAKE'
#!/bin/bash
[ "${1:-}" = "-e" ] || { cat >/dev/null; exit 0; }
script="$2"
echo "$script" >> "$TERMINAL/log"
case "$script" in
  *"set font name of settings set"*) echo "${script##* to \"}" | tr -d '"' > "$TERMINAL/font_name" ;;
  *"set font size of settings set"*) echo "${script##* to }" > "$TERMINAL/font_size" ;;
  *"to (font name of"*) echo "$(cat "$TERMINAL/font_name" 2>/dev/null || echo .AppleSystemUIFont) $(cat "$TERMINAL/font_size" 2>/dev/null || echo 11)" ;;
  *"delete settings set"*)
    name="${script#*settings set \"}"; name="${name%\"}"
    grep -vxF "$name" "$TERMINAL/profiles" > "$TERMINAL/p.tmp"; mv "$TERMINAL/p.tmp" "$TERMINAL/profiles" ;;
  *"name of startup settings"*) cat "$TERMINAL/startup" 2>/dev/null ;;
  *"name of default settings"*) cat "$TERMINAL/default" ;;
  *"exists settings set"*)
    name="${script#*settings set \"}"; name="${name%\"}"
    grep -qxF "$name" "$TERMINAL/profiles" && echo true || echo false ;;
  *"set default settings to settings set"*)
    name="${script#*settings set \"}"; name="${name%\"}"
    echo "$name" > "$TERMINAL/default" ;;
  *"set startup settings to settings set"*)
    name="${script#*settings set \"}"; name="${name%\"}"
    echo "$name" > "$TERMINAL/startup" ;;
esac
FAKE
  cat > "$FAKEBIN/open" <<'FAKE'
#!/bin/bash
echo "$1" >> "$TERMINAL/opened"
basename "$1" .terminal >> "$TERMINAL/profiles"
FAKE
  chmod +x "$FAKEBIN/osascript" "$FAKEBIN/open"
}
teardown() { teardown_isolated_env; }

@test "theme installs the font and makes Vellum the default" {
  run "$VELLUM_BIN" theme
  [ "$status" -eq 0 ]
  [ -f "$HOME/Library/Fonts/PaperMono-Regular.otf" ]
  [ -f "$HOME/Library/Fonts/PaperMono-Bold.otf" ]
  grep -qx Vellum "$TERMINAL/default"
  grep -qx Vellum "$TERMINAL/startup"
  grep -q "To go back to Man Page" <<<"$output"
}

@test "theme adds the profile only once" {
  "$VELLUM_BIN" theme
  "$VELLUM_BIN" theme
  [ "$(wc -l < "$TERMINAL/opened")" -eq 1 ]
}

@test "running theme again keeps the profile to go back to" {
  "$VELLUM_BIN" theme
  "$VELLUM_BIN" theme
  grep -qx "Man Page" "$HOME/.vellum/theme-previous"
}

@test "theme undo goes back to the earlier default" {
  "$VELLUM_BIN" theme
  run "$VELLUM_BIN" theme undo
  [ "$status" -eq 0 ]
  grep -qx "Man Page" "$TERMINAL/default"
  grep -qx "Man Page" "$TERMINAL/startup"
}

@test "theme undo with nothing to go back to says so" {
  run "$VELLUM_BIN" theme undo
  [ "$status" -ne 0 ]
  grep -q "no earlier Terminal profile" <<<"$output"
}

@test "the profile file is valid and uses Paper Mono" {
  plutil -lint "$VELLUM_REPO/theme/Vellum.terminal"
  plutil -extract Font raw -o - "$VELLUM_REPO/theme/Vellum.terminal" | base64 -D | grep -aq PaperMono-Regular
}

@test "theme replaces an older Vellum profile instead of adding a second one" {
  "$VELLUM_BIN" theme
  echo "an older version" > "$HOME/.vellum/theme-installed"
  run "$VELLUM_BIN" theme
  [ "$status" -eq 0 ]
  grep -q "Updated the Vellum profile" <<<"$output"
  grep -q 'delete settings set "Vellum"' "$TERMINAL/log"
  [ "$(grep -cx Vellum "$TERMINAL/profiles")" -eq 1 ]
  grep -qx Vellum "$TERMINAL/default"
  grep -qx Vellum "$TERMINAL/startup"
}

@test "theme leaves an up-to-date profile alone" {
  "$VELLUM_BIN" theme
  "$VELLUM_BIN" theme
  refute grep -q "delete settings set" "$TERMINAL/log"
}

@test "session start offers a theme update once, until skipped" {
  "$VELLUM_BIN" theme
  echo "an older version" > "$HOME/.vellum/theme-installed"
  run "$VELLUM_BIN" hook session-start < <(hook_input SessionStart /dev/null)
  grep -q "new version of the Vellum Terminal theme" <<<"$output"
  "$VELLUM_BIN" theme skip
  run "$VELLUM_BIN" hook session-start < <(hook_input SessionStart /dev/null)
  refute grep -q "Vellum Terminal theme" <<<"$output"
}

@test "session start says nothing about the theme if it was never installed" {
  run "$VELLUM_BIN" hook session-start < <(hook_input SessionStart /dev/null)
  refute grep -q "Vellum Terminal theme" <<<"$output"
}

@test "theme undo puts Claude Code's theme back from the installer's backup" {
  mkdir -p "$HOME/.claude"
  echo '{"theme": "dark"}' > "$HOME/.claude/settings.json.before-vellum"
  echo "{\"theme\": \"light-ansi\", \"model\": \"opus\", \"statusLine\": {\"type\": \"command\", \"command\": \"$HOME/.vellum/bin/vellum statusline\"}}" > "$HOME/.claude/settings.json"
  "$VELLUM_BIN" theme
  run "$VELLUM_BIN" theme undo
  [ "$status" -eq 0 ]
  /usr/bin/python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["theme"] == "dark" and d["model"] == "opus" and "statusLine" in d' "$HOME/.claude/settings.json"
  grep -q 'theme is back to "dark"' <<<"$output"
  grep -q 'status line is still on' <<<"$output"
  grep -qx "Man Page" "$TERMINAL/default"
}

@test "theme undo removes Claude Code's theme when there was none before" {
  mkdir -p "$HOME/.claude"
  echo '{}' > "$HOME/.claude/settings.json.before-vellum"
  echo '{"theme": "light-ansi"}' > "$HOME/.claude/settings.json"
  run "$VELLUM_BIN" theme undo
  [ "$status" -eq 0 ]
  refute grep -q theme "$HOME/.claude/settings.json"
  grep -q "no earlier Terminal profile" <<<"$output"
  grep -q "back to its default" <<<"$output"
}

@test "theme undo leaves a Claude Code theme the person changed since" {
  mkdir -p "$HOME/.claude"
  echo '{"theme": "dark"}' > "$HOME/.claude/settings.json.before-vellum"
  echo '{"theme": "light"}' > "$HOME/.claude/settings.json"
  "$VELLUM_BIN" theme
  run "$VELLUM_BIN" theme undo
  [ "$status" -eq 0 ]
  grep -q '"theme": "light"' "$HOME/.claude/settings.json"
  grep -q "left alone" <<<"$output"
}

@test "theme undo turns Claude Code's own recap back on" {
  mkdir -p "$HOME/.claude"
  echo '{}' > "$HOME/.claude/settings.json.before-vellum"
  echo '{"theme": "light-ansi", "awaySummaryEnabled": false}' > "$HOME/.claude/settings.json"
  run "$VELLUM_BIN" theme undo
  [ "$status" -eq 0 ]
  refute grep -q awaySummaryEnabled "$HOME/.claude/settings.json"
  grep -q "recap after five minutes away is back on" <<<"$output"
}

@test "theme sets Paper Mono 18 when Terminal fell back to the system font" {
  run "$VELLUM_BIN" theme
  [ "$status" -eq 0 ]
  grep -qx PaperMono-Regular "$TERMINAL/font_name"
  grep -qx 18 "$TERMINAL/font_size"
}

@test "theme installs Vellum's Claude Code theme and moves off plain light-ansi" {
  mkdir -p "$HOME/.claude"
  echo '{"theme": "light-ansi", "model": "opus"}' > "$HOME/.claude/settings.json"
  run "$VELLUM_BIN" theme
  [ "$status" -eq 0 ]
  cmp "$VELLUM_REPO/theme/claude-code.json" "$HOME/.claude/themes/vellum.json"
  /usr/bin/python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["theme"] == "custom:vellum" and d["model"] == "opus"' "$HOME/.claude/settings.json"
}

@test "theme leaves a Claude Code theme the person chose" {
  mkdir -p "$HOME/.claude"
  echo '{"theme": "dark"}' > "$HOME/.claude/settings.json"
  "$VELLUM_BIN" theme
  grep -q '"theme": "dark"' "$HOME/.claude/settings.json"
  [ -f "$HOME/.claude/themes/vellum.json" ]
}

@test "the Claude Code theme file is valid and builds on light-ansi" {
  /usr/bin/python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); assert d["base"] == "light-ansi" and d["overrides"]["promptBorder"].startswith("#")' "$VELLUM_REPO/theme/claude-code.json"
}
