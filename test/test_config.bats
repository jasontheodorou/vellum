#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "config: defaults" {
  run "$VELLUM_BIN" config
  [[ "$output" == *"background   = on"* ]] || false
  [[ "$output" == *"model        = default"* ]] || false
  [[ "$output" == *"projects-dir = $HOME/projects"* ]] || false
}

@test "config: background off and on" {
  "$VELLUM_BIN" config background off
  [ "$("$VELLUM_BIN" config background)" = "off" ]
  "$VELLUM_BIN" config background on
  [ "$("$VELLUM_BIN" config background)" = "on" ]
  [ "$(grep -c '^background=' "$HOME/.vellum/config")" -eq 1 ]
}

@test "config: rejects a bad background value" {
  run "$VELLUM_BIN" config background maybe
  [ "$status" -ne 0 ]
}

@test "config: model" {
  "$VELLUM_BIN" config model haiku
  [ "$("$VELLUM_BIN" config model)" = "haiku" ]
}

@test "config: rejects an unknown setting" {
  run "$VELLUM_BIN" config colour blue
  [ "$status" -ne 0 ]
}

@test "version matches plugin.json" {
  version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$VELLUM_REPO/.claude-plugin/plugin.json")
  run "$VELLUM_BIN" version
  [ "$output" = "$version" ]
}

@test "unknown command fails with help" {
  run "$VELLUM_BIN" frobnicate
  [ "$status" -eq 2 ]
  [[ "$output" == *"vellum help"* ]] || false
}
