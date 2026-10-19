#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

FIXTURE="$VELLUM_REPO/test/fixtures/session.jsonl"

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
  jq -r -f "$VELLUM_REPO/templates/condense.jq" "$FIXTURE" > "$TEST_HOME/out.txt"
  check_condensed "$TEST_HOME/out.txt"
}

@test "condense with python3 gives the same result as jq" {
  command -v jq >/dev/null || skip "jq not installed"
  command -v python3 >/dev/null || skip "python3 not installed"
  jq -r -f "$VELLUM_REPO/templates/condense.jq" "$FIXTURE" > "$TEST_HOME/jq.txt"
  mkdir -p "$TEST_HOME/nojq"
  for t in bash sh sed awk grep cat rm mkdir dirname basename python3; do
    p=$(command -v $t) && ln -sf "$p" "$TEST_HOME/nojq/$t"
  done
  # Run the script's own function with jq hidden.
  PATH="$TEST_HOME/nojq" bash -c "TEMPLATES='$VELLUM_REPO/templates'; source '$VELLUM_REPO/lib/common.sh'; source '$VELLUM_REPO/lib/journal.sh'; condense_transcript '$FIXTURE' '$TEST_HOME/py.txt'"
  check_condensed "$TEST_HOME/py.txt"
  diff "$TEST_HOME/jq.txt" "$TEST_HOME/py.txt"
}

@test "condense shrinks a transcript" {
  command -v jq >/dev/null || skip "jq not installed"
  jq -r -f "$VELLUM_REPO/templates/condense.jq" "$FIXTURE" > "$TEST_HOME/out.txt"
  [ "$(wc -c < "$TEST_HOME/out.txt")" -lt $(( $(wc -c < "$FIXTURE") / 4 )) ]
}

@test "condense skips lines that are not the expected shape, with jq and with python3" {
  bad="$TEST_HOME/bad.jsonl"
  cat > "$bad" <<'JSONL'
{"type":"user","message":{"content":["a string block"]}}
[1,2,3]
"just a string"
{"type":"assistant","message":"not an object"}
{"type":"assistant","message":{"content":[{"type":"text","text":"hello"},5,null,{"type":"tool_use","name":"Bash","input":{"command":"ls"}}]}}
{"type":"user","message":{"content":[{"type":"text","text":null}]}}
{"type":"user", "half written
JSONL
  mkdir -p "$TEST_HOME/nojq"
  for t in bash sh sed awk grep cat rm mkdir dirname basename python3; do
    p=$(command -v $t) && ln -sf "$p" "$TEST_HOME/nojq/$t"
  done
  PATH="$TEST_HOME/nojq" bash -c "TEMPLATES='$VELLUM_REPO/templates'; source '$VELLUM_REPO/lib/common.sh'; source '$VELLUM_REPO/lib/journal.sh'; condense_transcript '$bad' '$TEST_HOME/py.txt'"
  printf 'PERSON: a string block\nCLAUDE: hello\nACTION: Bash ls\n' > "$TEST_HOME/want.txt"
  diff "$TEST_HOME/want.txt" "$TEST_HOME/py.txt"
  if command -v jq >/dev/null; then
    bash -c "TEMPLATES='$VELLUM_REPO/templates'; source '$VELLUM_REPO/lib/common.sh'; source '$VELLUM_REPO/lib/journal.sh'; condense_transcript '$bad' '$TEST_HOME/jq.txt'"
    diff "$TEST_HOME/want.txt" "$TEST_HOME/jq.txt"
  fi
}
