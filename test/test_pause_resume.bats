#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; "$VELLUM_BIN" init >/dev/null; }
teardown() { teardown_isolated_env; }

@test "pause creates the marker" {
  run "$VELLUM_BIN" pause
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.vellum/.paused" ]
}

@test "resume removes the marker" {
  "$VELLUM_BIN" pause
  run "$VELLUM_BIN" resume
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.vellum/.paused" ]
}

@test "resume when not paused succeeds" {
  run "$VELLUM_BIN" resume
  [ "$status" -eq 0 ]
}

@test "pause without a journal explains how to turn it on" {
  rm -rf "$PROJECT_DIR/.vellum"
  run "$VELLUM_BIN" pause
  [ "$status" -ne 0 ]
  [[ "$output" == *"vellum init"* ]] || false
}
