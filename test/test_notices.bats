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
  [ "$output" = "garden: 1 decision and lessons" ]
}

@test "notices: the next session start shows it once, as a message to the person" {
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  out=$(printf '{"cwd":"%s","session_id":"s2"}' "$P/garden" | "$SCRIBE_BIN" hook session-start)
  printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["systemMessage"] == "Journal updated after your last session. garden: 1 decision and lessons.", d["systemMessage"]; assert "Journal for garden" in d["hookSpecificOutput"]["additionalContext"]'
  again=$(printf '{"cwd":"%s","session_id":"s3"}' "$P/garden" | "$SCRIBE_BIN" hook session-start)
  [[ "$again" != *"systemMessage"* ]]
}

@test "notices: the home folder shows messages for every project" {
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  out=$(printf '{"cwd":"%s","session_id":"s2"}' "$HOME" | "$SCRIBE_BIN" hook session-start)
  [[ "$out" == *'"systemMessage":"Journal updated after your last session. garden: 1 decision and lessons."'* ]]
}

@test "notices: another project's message waits for that project" {
  "$SCRIBE_BIN" new other >/dev/null
  end_session
  wait_for_file "$HOME/.scribe/notices/$("$SCRIBE_BIN" __sanitize "$P/garden")"
  out=$(printf '{"cwd":"%s","session_id":"s2"}' "$P/other" | "$SCRIBE_BIN" hook session-start)
  [[ "$out" != *"systemMessage"* ]]
  [ -n "$(ls "$HOME/.scribe/notices")" ]
}

@test "notices: nothing changed means no message" {
  printf '#!/bin/bash\ncat >/dev/null\n' > "$FAKEBIN/claude"
  end_session
  wait_for_file "$P/garden/.scribe/.state/s1"
  sleep 0.3
  [ -z "$(ls "$HOME/.scribe/notices" 2>/dev/null)" ]
}
