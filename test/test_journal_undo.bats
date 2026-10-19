#!/usr/bin/env bats

load helpers

# A fake curator that records a decision and a lesson, or changes nothing
# when $TEST_HOME/quiet exists.
setup() {
  setup_isolated_env
  "$VELLUM_BIN" init >/dev/null
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
[ -f "$TEST_HOME/quiet" ] && exit 0
n=$(ls .vellum/decisions/*.md 2>/dev/null | wc -l | tr -d ' ')
echo "# Decision $((n + 1))" > ".vellum/decisions/00$((n + 1))-choice.md"
echo "### Lesson: number $((n + 1))" >> .vellum/lessons.md
FAKE
  chmod +x "$FAKEBIN/claude"
  J="$PROJECT_DIR/.vellum"
}
teardown() { teardown_isolated_env; }

@test "undo: keeps notes written after the curator ran" {
  "$VELLUM_BIN" curate >/dev/null
  echo "# Next session" > "$J/logbook/2099-01-01.md"
  run "$VELLUM_BIN" undo
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 files put back"* ]] || false
  [ -f "$J/logbook/2099-01-01.md" ]
  [ ! -f "$J/decisions/001-choice.md" ]
  refute grep -q "Lesson: number 1" "$J/lessons.md"
}

@test "undo: refuses and names the files when the curator's changes were edited since" {
  "$VELLUM_BIN" curate >/dev/null
  echo "my own lesson" >> "$J/lessons.md"
  run "$VELLUM_BIN" undo
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing was undone"* ]] || false
  [[ "$output" == *".vellum/lessons.md"* ]] || false
  [[ "$output" != *"decisions/001-choice.md"* ]] || false
  [ -f "$J/decisions/001-choice.md" ]
  grep -q "my own lesson" "$J/lessons.md"
  [ -z "$(ls "$J/.state/snapshots" | grep before-undo)" ]
}

@test "undo: removes the project's 'Journal updated' notice" {
  "$VELLUM_BIN" curate >/dev/null
  mkdir -p "$HOME/.vellum/notices"
  echo "Journal updated" > "$HOME/.vellum/notices/$("$VELLUM_BIN" __sanitize "$PROJECT_DIR")"
  echo "Other project" > "$HOME/.vellum/notices/other"
  "$VELLUM_BIN" undo >/dev/null
  [ ! -f "$HOME/.vellum/notices/$("$VELLUM_BIN" __sanitize "$PROJECT_DIR")" ]
  [ -f "$HOME/.vellum/notices/other" ]
}

@test "undo: a curator run that changed nothing leaves nothing to undo" {
  touch "$TEST_HOME/quiet"
  run "$VELLUM_BIN" curate
  [ "$status" -eq 0 ]
  [[ "$output" == *"made no changes"* ]] || false
  [ -z "$(ls "$J/.state/snapshots")" ]
  run "$VELLUM_BIN" undo
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to undo"* ]] || false
}

@test "undo: a second undo does not quietly step further back" {
  "$VELLUM_BIN" curate >/dev/null
  sleep 1
  "$VELLUM_BIN" curate >/dev/null
  [ -f "$J/decisions/002-choice.md" ]
  run "$VELLUM_BIN" undo
  [ "$status" -eq 0 ]
  [[ "$output" == *"undo --earlier"* ]] || false
  [ ! -f "$J/decisions/002-choice.md" ]
  [ -f "$J/decisions/001-choice.md" ]
  run "$VELLUM_BIN" undo
  [ "$status" -ne 0 ]
  [[ "$output" == *"already undone"* ]] || false
  [ -f "$J/decisions/001-choice.md" ]
  run "$VELLUM_BIN" undo --earlier
  [ "$status" -eq 0 ]
  [ ! -f "$J/decisions/001-choice.md" ]
}

@test "undo: a new curator update can be undone without --earlier" {
  "$VELLUM_BIN" curate >/dev/null
  "$VELLUM_BIN" undo >/dev/null
  sleep 1
  "$VELLUM_BIN" curate >/dev/null
  run "$VELLUM_BIN" undo
  [ "$status" -eq 0 ]
  [ ! -f "$J/decisions/001-choice.md" ]
}

@test "undo: keeps only the three most recent copies saved by undo" {
  mkdir -p "$J/.state/snapshots"
  for i in 1 2 3 4 5; do touch "$J/.state/snapshots/2026-01-0$i-000000-before-undo.tgz"; done
  "$VELLUM_BIN" curate >/dev/null
  "$VELLUM_BIN" undo >/dev/null
  [ "$(ls "$J/.state/snapshots" | grep -c before-undo)" -eq 3 ]
  [ ! -f "$J/.state/snapshots/2026-01-03-000000-before-undo.tgz" ]
}

@test "curate and undo wait for a curator that is already running" {
  mkdir -p "$J/.state/lock"
  run "$VELLUM_BIN" curate
  [ "$status" -ne 0 ]
  [[ "$output" == *"curator is working on this journal"* ]] || false
  [ ! -f "$TEST_HOME/claude.stdin" ]
  run "$VELLUM_BIN" undo
  [ "$status" -ne 0 ]
  [[ "$output" == *"curator is working on this journal"* ]] || false
  [ -d "$J/.state/lock" ]
  rmdir "$J/.state/lock"
}

@test "curate takes the curator lock while it runs and gives it back" {
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
cat >/dev/null
[ -d .vellum/.state/lock ] && touch "$TEST_HOME/locked"
FAKE
  chmod +x "$FAKEBIN/claude"
  "$VELLUM_BIN" curate >/dev/null
  [ -f "$TEST_HOME/locked" ]
  [ ! -d "$J/.state/lock" ]
}

@test "curate gives the lock back when the curator fails" {
  printf '#!/bin/bash\ncat >/dev/null\nexit 1\n' >"$FAKEBIN/claude"
  run "$VELLUM_BIN" curate
  [ "$status" -ne 0 ]
  [ ! -d "$J/.state/lock" ]
}

@test "undo: a stale lock does not block it" {
  "$VELLUM_BIN" curate >/dev/null
  mkdir -p "$J/.state/lock"
  touch -t 202001010000 "$J/.state/lock"
  run "$VELLUM_BIN" undo
  [ "$status" -eq 0 ]
}
