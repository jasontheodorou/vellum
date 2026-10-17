#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "desktop path: ~/Desktop when it exists" {
  mkdir -p "$HOME/Desktop"
  run "$SCRIBE_BIN" __desktop_path
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/Desktop" ]
}

@test "desktop path: home folder when there is no desktop" {
  run "$SCRIBE_BIN" __desktop_path
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "$HOME" ]
}
