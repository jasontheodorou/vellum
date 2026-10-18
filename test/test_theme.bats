#!/usr/bin/env bats
# The Terminal theme. Fake osascript and open stand in for Terminal.

load helpers

setup() {
  setup_isolated_env
  TERMINAL="$TEST_HOME/terminal"
  mkdir -p "$TERMINAL"
  echo "Man Page" > "$TERMINAL/default"
  echo "Man Page" > "$TERMINAL/profiles"
  export TERMINAL
  cat > "$FAKEBIN/osascript" <<'FAKE'
#!/bin/bash
script="$2"
case "$script" in
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
