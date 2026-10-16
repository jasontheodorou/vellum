#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

FIXTURE="$SCRIBE_REPO/test/fixtures/session.jsonl"

check_condensed() {
  local out="$1"
  grep -qx "PERSON: Can we move sign-in to magic links? Passwords keep getting reset." "$out"
  grep -qx "CLAUDE: Yes. I will replace the password form with an email link." "$out"
  grep -qx "ACTION: Edit src/auth/signin.tsx" "$out"
  grep -qx "ACTION: Bash npm test" "$out"
  grep -qx "FAILED: 2 tests failed in signin" "$out"
  grep -qx "PERSON: too busy, keep it to one column" "$out"
  refute grep -q "secret thoughts" "$out"
  refute grep -q "BIG TOOL OUTPUT" "$out"
  refute grep -q "meta caveat" "$out"
  refute grep -q "system record" "$out"
}

@test "condense with jq keeps the conversation and drops the rest" {
  command -v jq >/dev/null || skip "jq not installed"
  jq -r -f "$SCRIBE_REPO/templates/condense.jq" "$FIXTURE" > "$TEST_HOME/out.txt"
  check_condensed "$TEST_HOME/out.txt"
}

@test "condense with python3 gives the same result as jq" {
  command -v jq >/dev/null || skip "jq not installed"
  command -v python3 >/dev/null || skip "python3 not installed"
  jq -r -f "$SCRIBE_REPO/templates/condense.jq" "$FIXTURE" > "$TEST_HOME/jq.txt"
  mkdir -p "$TEST_HOME/nojq"
  for t in bash sh sed awk grep cat rm mkdir dirname basename python3; do
    p=$(command -v $t) && ln -sf "$p" "$TEST_HOME/nojq/$t"
  done
  # Run the script's own function with jq hidden.
  sed '/^main "\$@"$/d' "$SCRIBE_BIN" > "$TEST_HOME/lib.sh"
  PATH="$TEST_HOME/nojq" bash -c "source '$TEST_HOME/lib.sh'; condense_transcript '$FIXTURE' '$TEST_HOME/py.txt'"
  check_condensed "$TEST_HOME/py.txt"
  diff "$TEST_HOME/jq.txt" "$TEST_HOME/py.txt"
}

@test "condense shrinks a transcript" {
  command -v jq >/dev/null || skip "jq not installed"
  jq -r -f "$SCRIBE_REPO/templates/condense.jq" "$FIXTURE" > "$TEST_HOME/out.txt"
  [ "$(wc -c < "$TEST_HOME/out.txt")" -lt $(( $(wc -c < "$FIXTURE") / 4 )) ]
}
