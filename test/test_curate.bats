#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; install_fake_claude; "$VELLUM_BIN" init >/dev/null; }
teardown() { teardown_isolated_env; }

@test "curate runs the curator with no shell and edits limited to the journal" {
  run "$VELLUM_BIN" curate
  [ "$status" -eq 0 ]
  grep -qx "Read,Glob,Grep,Edit,Write" "$TEST_HOME/claude.args"
  grep -qx "Edit(./.vellum/\*\*)" "$TEST_HOME/claude.args"
  grep -qx "dontAsk" "$TEST_HOME/claude.args"
}

@test "curate tells the curator there is no new session" {
  "$VELLUM_BIN" curate
  grep -q "There is no new session to record" "$TEST_HOME/claude.stdin"
  refute grep -q "{{" "$TEST_HOME/claude.stdin"
}

@test "curate fills in the project name and date" {
  "$VELLUM_BIN" curate
  grep -q '"test-project"' "$TEST_HOME/claude.stdin"
  grep -q "Today is $(date '+%Y-%m-%d')" "$TEST_HOME/claude.stdin"
}

@test "curate fails clearly without claude" {
  rm -f "$FAKEBIN/claude"
  run "$VELLUM_BIN" curate
  [ "$status" -ne 0 ]
  [[ "$output" == *"not on PATH"* ]] || false
}

@test "curate needs a journal" {
  rm -rf "$PROJECT_DIR/.vellum"
  run "$VELLUM_BIN" curate
  [ "$status" -ne 0 ]
}
