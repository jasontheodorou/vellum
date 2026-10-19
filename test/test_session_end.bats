#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  install_fake_claude
  make_git_repo
  "$VELLUM_BIN" init >/dev/null
  TRANSCRIPT="$VELLUM_REPO/test/fixtures/session.jsonl"
}
teardown() { teardown_isolated_env; }

end_hook() {
  hook_input SessionEnd "$1" "${2:-sess-1}" | "$VELLUM_BIN" hook session-end
}

@test "session-end: starts the curator for a real session" {
  run end_hook "$TRANSCRIPT"
  [ "$status" -eq 0 ]
  wait_for_file "$TEST_HOME/claude.args"
}

@test "session-end: the curator cannot use the shell or bypass permissions" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-1"
  grep -qx "Read,Glob,Grep,Edit,Write" "$TEST_HOME/claude.args"
  grep -qx "dontAsk" "$TEST_HOME/claude.args"
  grep -qx "Edit(./.vellum/\*\*)" "$TEST_HOME/claude.args"
  refute grep -q "bypassPermissions" "$TEST_HOME/claude.args"
  refute grep -q "Bash" "$TEST_HOME/claude.args"
  grep -qx "VELLUM_SUBAGENT=1" "$TEST_HOME/claude.env"
}

@test "session-end: the curator reads a condensed copy of the session" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-1"
  grep -q "./.vellum/.state/session-sess-1.txt" "$TEST_HOME/claude.stdin"
  refute grep -q "$TRANSCRIPT" "$TEST_HOME/claude.stdin"
  grep -q "Never copy passwords" "$TEST_HOME/claude.stdin"
  refute grep -q "{{" "$TEST_HOME/claude.stdin"
}

@test "session-end: tidies up the condensed copy and rebuilds the index" {
  rm -f "$PROJECT_DIR/.vellum/INDEX.md"
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.vellum/INDEX.md"
  sleep 0.2
  [ ! -f "$PROJECT_DIR/.vellum/.state/session-sess-1.txt" ]
  [ ! -d "$PROJECT_DIR/.vellum/.state/lock" ]
}

@test "session-end: falls back to the raw transcript when it cannot be condensed" {
  old="$VELLUM_REPO/test/fixtures/transcript.jsonl"
  end_hook "$old"
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-1"
  grep -qx "Edit(./.vellum/\*\*),Read(/$old)" "$TEST_HOME/claude.args"
  grep -q "$old" "$TEST_HOME/claude.stdin"
}

@test "session-end: the curator does not show up in git status" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-1"
  [ -z "$(git -C "$PROJECT_DIR" status --porcelain)" ]
}

@test "session-end: skips a transcript it has already read" {
  end_hook "$TRANSCRIPT"
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-1"
  rm -f "$TEST_HOME/claude.args"
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips when paused" {
  "$VELLUM_BIN" pause >/dev/null
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips when the background curator is off" {
  "$VELLUM_BIN" config background off >/dev/null
  end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: skips without a journal" {
  rm -rf "$PROJECT_DIR/.vellum"
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

@test "session-end: waits while vellum curate holds the project's lock, then runs" {
  mkdir -p "$PROJECT_DIR/.vellum/.state/lock"
  end_hook "$TRANSCRIPT"
  sleep 1.5
  [ ! -f "$TEST_HOME/claude.args" ]
  grep -q "waiting for another curator" "$HOME/.vellum/vellum.log"
  rmdir "$PROJECT_DIR/.vellum/.state/lock"
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-1"
}

@test "session-end: silent inside a curator session" {
  VELLUM_SUBAGENT=1 end_hook "$TRANSCRIPT"
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
}

@test "session-end: returns at once while the curator is still running" {
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
sleep 3
FAKE
  chmod +x "$FAKEBIN/claude"
  start=$(date +%s)
  end_hook "$TRANSCRIPT"
  [ $(( $(date +%s) - start )) -lt 2 ]
}

# Wait up to N seconds for a file.
wait_long() {
  local _
  for _ in $(seq 1 $(( $2 * 10 ))); do
    [ -f "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

now_ms() { perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000'; }

@test "session-end: the hook does not read the transcript, so a huge one is still quick" {
  big="$TEST_HOME/big.jsonl"
  for _ in $(seq 1 8); do cat "$TRANSCRIPT"; done > "$big.part"
  for _ in $(seq 1 1000); do cat "$big.part"; done > "$big"
  rm -f "$big.part"
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
FAKE
  chmod +x "$FAKEBIN/claude"
  start=$(now_ms)
  end_hook "$big"
  [ $(( $(now_ms) - start )) -lt 1000 ]
  wait_long "$PROJECT_DIR/.vellum/.state/sess-1" 20
}

@test "session-end: the curator runs in its own process group, so closing the window does not stop it" {
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
ps -o pgid= -p $$ | tr -d ' ' > "$TEST_HOME/curator.pgid"
FAKE
  chmod +x "$FAKEBIN/claude"
  end_hook "$TRANSCRIPT"
  wait_for_file "$TEST_HOME/curator.pgid"
  [ "$(cat "$TEST_HOME/curator.pgid")" != "$(ps -o pgid= -p $$ | tr -d ' ')" ]
}

@test "session-end: a session that ends while the curator is busy is queued, then curated" {
  sleep 30 &
  busy=$!
  mkdir -p "$HOME/.vellum/.state/lock"
  echo "$busy" > "$HOME/.vellum/.state/lock/pid"
  end_hook "$TRANSCRIPT" sess-1
  sleep 0.5
  [ ! -f "$TEST_HOME/claude.args" ]
  ls "$HOME/.vellum/.state/queue"/*sess-1.job
  grep -q "waits in the queue" "$HOME/.vellum/vellum.log"
  # The busy curator stops without letting go of its lock: that lock is stale.
  kill "$busy"
  wait "$busy" 2>/dev/null || true
  end_hook "$TRANSCRIPT" sess-2
  wait_long "$PROJECT_DIR/.vellum/.state/sess-2" 10
  wait_long "$PROJECT_DIR/.vellum/.state/sess-1" 10
  grep -q "cleared a stale lock" "$HOME/.vellum/vellum.log"
}

@test "session-end: the running curator works through sessions queued while it runs" {
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
sleep 1
FAKE
  chmod +x "$FAKEBIN/claude"
  end_hook "$TRANSCRIPT" sess-1
  end_hook "$TRANSCRIPT" sess-2
  end_hook "$TRANSCRIPT" sess-3
  wait_long "$PROJECT_DIR/.vellum/.state/sess-1" 15
  wait_long "$PROJECT_DIR/.vellum/.state/sess-2" 15
  wait_long "$PROJECT_DIR/.vellum/.state/sess-3" 15
}

@test "session-end: the projects a session opened are kept until the job is queued" {
  mkdir -p "$HOME/.vellum/sessions"
  echo "$PROJECT_DIR" > "$HOME/.vellum/sessions/sess-1"
  "$VELLUM_BIN" config background off >/dev/null
  end_hook "$TRANSCRIPT"
  [ ! -f "$HOME/.vellum/sessions/sess-1" ]
  "$VELLUM_BIN" config background on >/dev/null
  echo "$PROJECT_DIR" > "$HOME/.vellum/sessions/sess-2"
  end_hook "$TRANSCRIPT" sess-2
  [ ! -f "$HOME/.vellum/sessions/sess-2" ]
  wait_for_file "$PROJECT_DIR/.vellum/.state/sess-2"
}

@test "session-end: a paused project's conversation is never kept for recall" {
  "$VELLUM_BIN" pause >/dev/null
  end_hook "$TRANSCRIPT"
  wait_for_file "$HOME/.vellum/vellum.log"
  sleep 1.5
  grep -q "recall skipped" "$HOME/.vellum/vellum.log"
  [ ! -f "$HOME/.vellum/recall/session.txt" ]
}

@test "session-end: a declined folder's conversation is never kept for recall" {
  rm -rf "$PROJECT_DIR/.vellum"
  "$VELLUM_BIN" init --decline >/dev/null
  end_hook "$TRANSCRIPT"
  wait_for_file "$HOME/.vellum/vellum.log"
  sleep 1.5
  grep -q "recall skipped" "$HOME/.vellum/vellum.log"
  [ ! -f "$HOME/.vellum/recall/session.txt" ]
}
