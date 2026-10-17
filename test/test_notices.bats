#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  P="$HOME/projects"
  "$SCRIBE_BIN" new garden >/dev/null
  # A fake curator that records a decision and a lesson.
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
echo "# 001 Raised beds" > .scribe/decisions/001-raised-beds.md
echo "### Lesson: clay drains badly" >> .scribe/lessons.md
echo "Recorded one decision."
FAKE
  chmod +x "$FAKEBIN/claude"
  T="$SCRIBE_REPO/test/fixtures/session.jsonl"
}
teardown() { teardown_isolated_env; }

end_session() {
  printf '{"cwd":"%s","session_id":"s1","transcript_path":"%s"}' "$P/garden" "$T" | "$SCRIBE_BIN" hook session-end
}

@test "notices: the curator leaves a message saying what changed" {
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  run cat "$HOME/.scribe/notices/"*
  [ "$output" = 'Journal updated after your last session: garden, 1 decision and lessons. Say "undo the journal update" to reverse it.' ]
}

@test "notices: the next session start shows it once, as a message to the person" {
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  out=$(printf '{"cwd":"%s","session_id":"s2"}' "$P/garden" | "$SCRIBE_BIN" hook session-start)
  printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["systemMessage"].startswith("Journal updated after your last session: garden, 1 decision and lessons."), d["systemMessage"]; assert "Journal for garden" in d["hookSpecificOutput"]["additionalContext"]'
  again=$(printf '{"cwd":"%s","session_id":"s3"}' "$P/garden" | "$SCRIBE_BIN" hook session-start)
  [[ "$again" != *"systemMessage"* ]] || false
}

@test "notices: the home folder shows messages for every project" {
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  out=$(printf '{"cwd":"%s","session_id":"s2"}' "$HOME" | "$SCRIBE_BIN" hook session-start)
  [[ "$out" == *'"systemMessage":"Journal updated after your last session: garden, 1 decision and lessons.'* ]] || false
}

@test "notices: another project's message waits for that project" {
  "$SCRIBE_BIN" new other >/dev/null
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  out=$(printf '{"cwd":"%s","session_id":"s2"}' "$P/other" | "$SCRIBE_BIN" hook session-start)
  [[ "$out" != *"systemMessage"* ]] || false
  [ -n "$(ls "$HOME/.scribe/notices")" ]
}

@test "notices: nothing changed means no message" {
  printf '#!/bin/bash\ncat >/dev/null\n' > "$FAKEBIN/claude"
  end_session
  wait_for_file "$P/garden/.scribe/.state/s1"
  sleep 0.3
  [ -z "$(ls "$HOME/.scribe/notices" 2>/dev/null)" ]
}

@test "notices: a failed curator run is reported" {
  printf '#!/bin/bash\ncat >/dev/null\nexit 1\n' > "$FAKEBIN/claude"
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  grep -q "The curator could not update garden's journal" "$HOME/.scribe/notices/"*
}

@test "undo: puts the journal back as it was before the curator ran" {
  echo "my own lesson" >> "$P/garden/.scribe/lessons.md"
  end_session
  wait_for_file "$P/garden/.scribe/.state/s1"
  sleep 0.3
  [ -f "$P/garden/.scribe/decisions/001-raised-beds.md" ]
  cd "$P/garden"
  run "$SCRIBE_BIN" undo
  [ "$status" -eq 0 ]
  [[ "$output" == *"The journal is back as it was on"* ]] || false
  [ ! -f "$P/garden/.scribe/decisions/001-raised-beds.md" ]
  grep -q "my own lesson" "$P/garden/.scribe/lessons.md"
  refute grep -q "clay drains badly" "$P/garden/.scribe/lessons.md"
  ls "$P/garden/.scribe/.state/snapshots/" | grep -q -- '-before-undo.tgz'
}

@test "undo: keeps artefacts and the pause marker untouched" {
  echo "old design" > "$P/garden/.scribe/artefacts/2026-01-01-home.css"
  end_session
  wait_for_file "$P/garden/.scribe/.state/s1"
  sleep 0.3
  touch "$P/garden/.scribe/.paused"
  cd "$P/garden"
  "$SCRIBE_BIN" undo >/dev/null
  [ -f "$P/garden/.scribe/artefacts/2026-01-01-home.css" ]
  [ -f "$P/garden/.scribe/.paused" ]
}

@test "undo: says so when there is nothing to undo" {
  cd "$P/garden"
  run "$SCRIBE_BIN" undo
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to undo"* ]] || false
}

@test "undo: keeps only the ten most recent snapshots" {
  cd "$P/garden"
  mkdir -p .scribe/.state/snapshots
  for i in $(seq -w 1 12); do touch ".scribe/.state/snapshots/2026-01-$i-000000.tgz"; done
  bash -c "export TEMPLATES='$SCRIBE_REPO/templates' SCRIBE_HOME='$HOME/.scribe'; source '$SCRIBE_REPO/lib/common.sh'; source '$SCRIBE_REPO/lib/journal.sh'; set_project '$P/garden'; snapshot_journal"
  [ "$(ls .scribe/.state/snapshots | grep -vc before-undo)" -eq 10 ]
  [ ! -f .scribe/.state/snapshots/2026-01-01-000000.tgz ]
}
