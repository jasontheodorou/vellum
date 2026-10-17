#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "status: not on" {
  run "$SCRIBE_BIN" status
  [ "$status" -eq 0 ]
  [[ "$output" == *"not on"* ]] || false
}

@test "status: declined" {
  "$SCRIBE_BIN" init --decline
  run "$SCRIBE_BIN" status
  [[ "$output" == *"said no"* ]] || false
}

@test "status: old journal" {
  mkdir -p "$PROJECT_DIR/journal"
  printf '<!-- scribe-block-begin -->\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  run "$SCRIBE_BIN" status
  [[ "$output" == *"migrate"* ]] || false
}

@test "status: on, with counts and the last entry" {
  "$SCRIBE_BIN" init
  echo "x" > "$PROJECT_DIR/.scribe/logbook/2026-04-30.md"
  echo "x" > "$PROJECT_DIR/.scribe/decisions/001-a.md"
  run "$SCRIBE_BIN" status
  [[ "$output" == *"Journaling is on"* ]] || false
  [[ "$output" == *"logbook entries: 1"* ]] || false
  [[ "$output" == *"decisions:       1"* ]] || false
  [[ "$output" == *"2026-04-30"* ]] || false
}

@test "status: paused" {
  "$SCRIBE_BIN" init
  "$SCRIBE_BIN" pause
  run "$SCRIBE_BIN" status
  [[ "$output" == *"paused"* ]] || false
}
