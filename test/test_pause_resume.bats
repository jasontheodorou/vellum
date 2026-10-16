#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; "$SCRIBE_BIN" init >/dev/null; }
teardown() { teardown_isolated_env; }

@test "pause creates the marker" {
  run "$SCRIBE_BIN" pause
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.scribe/.paused" ]
}

@test "resume removes the marker" {
  "$SCRIBE_BIN" pause
  run "$SCRIBE_BIN" resume
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.scribe/.paused" ]
}

@test "resume when not paused succeeds" {
  run "$SCRIBE_BIN" resume
  [ "$status" -eq 0 ]
}

@test "pause without a journal explains how to turn it on" {
  rm -rf "$PROJECT_DIR/.scribe"
  run "$SCRIBE_BIN" pause
  [ "$status" -ne 0 ]
  [[ "$output" == *"scribe init"* ]]
}
