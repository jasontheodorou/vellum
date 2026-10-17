#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "config: defaults" {
  run "$SCRIBE_BIN" config
  [[ "$output" == *"background   = on"* ]] || false
  [[ "$output" == *"model        = default"* ]] || false
  [[ "$output" == *"projects-dir = $HOME/projects"* ]] || false
}

@test "config: background off and on" {
  "$SCRIBE_BIN" config background off
  [ "$("$SCRIBE_BIN" config background)" = "off" ]
  "$SCRIBE_BIN" config background on
  [ "$("$SCRIBE_BIN" config background)" = "on" ]
  [ "$(grep -c '^background=' "$HOME/.scribe/config")" -eq 1 ]
}

@test "config: rejects a bad background value" {
  run "$SCRIBE_BIN" config background maybe
  [ "$status" -ne 0 ]
}

@test "config: model" {
  "$SCRIBE_BIN" config model haiku
  [ "$("$SCRIBE_BIN" config model)" = "haiku" ]
}

@test "config: rejects an unknown setting" {
  run "$SCRIBE_BIN" config colour blue
  [ "$status" -ne 0 ]
}

@test "version matches plugin.json" {
  version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$SCRIBE_REPO/.claude-plugin/plugin.json")
  run "$SCRIBE_BIN" version
  [ "$output" = "$version" ]
}

@test "unknown command fails with help" {
  run "$SCRIBE_BIN" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"scribe help"* ]] || false
}
