#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  install_fake_claude
  make_git_repo
  "$SCRIBE_BIN" init >/dev/null
  TRANSCRIPT="$SCRIBE_REPO/test/fixtures/transcript.jsonl"
}
teardown() { teardown_isolated_env; }

end_hook() {
  hook_input SessionEnd "$1" "${2:-sess-1}" | "$SCRIBE_BIN" hook session-end
}

@test "session-end: starts a helper for a real session" {
  run end_hook "$TRANSCRIPT"
  [ "$status" -eq 0 ]
  wait_for_file "$TEST_HOME/claude.args"
}

@test "session-end: the helper cannot use the shell or bypass permissions" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.scribe/.state/sess-1"
  grep -qx "Read,Glob,Grep,Edit,Write" "$TEST_HOME/claude.args"
  grep -qx "dontAsk" "$TEST_HOME/claude.args"
  grep -qx "Edit(./.scribe/\*\*),Read(/$TRANSCRIPT)" "$TEST_HOME/claude.args"
  refute grep -q "bypassPermissions" "$TEST_HOME/claude.args"
  refute grep -q "Bash" "$TEST_HOME/claude.args"
  grep -qx "SCRIBE_SUBAGENT=1" "$TEST_HOME/claude.env"
}

@test "session-end: the prompt names the transcript and forbids secrets" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.scribe/.state/sess-1"
  grep -q "$TRANSCRIPT" "$TEST_HOME/claude.stdin"
  grep -q "Never copy passwords" "$TEST_HOME/claude.stdin"
}

@test "session-end: the helper does not show up in git status" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.scribe/.state/sess-1"
  [ -z "$(git -C "$PROJECT_DIR" status --porcelain)" ]
}

@test "session-end: skips a transcript it has already read" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.scribe/.state/sess-1"
  rm -f "$TEST_HOME/claude.args"
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips when paused" {
  "$SCRIBE_BIN" pause >/dev/null
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips when the background helper is off" {
  "$SCRIBE_BIN" config background off >/dev/null
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips without a journal" {
  rm -rf "$PROJECT_DIR/.scribe"
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips a short transcript" {
  echo tiny > "$TEST_HOME/tiny.jsonl"
  end_hook "$TEST_HOME/tiny.jsonl"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips a missing transcript" {
  end_hook "$TEST_HOME/missing.jsonl"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips while another helper holds the lock" {
  mkdir -p "$PROJECT_DIR/.scribe/.state/lock"
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: silent inside a helper session" {
  SCRIBE_SUBAGENT=1 end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: returns at once while the helper is still running" {
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
sleep 3
FAKE
  chmod +x "$FAKEBIN/claude"
  start=$(date +%s)
  end_hook "$TRANSCRIPT"
  [ $(( $(date +%s) - start )) -lt 2 ]
}
