#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "init creates the .scribe journal" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$PROJECT_DIR/.scribe/logbook" ]
  [ -d "$PROJECT_DIR/.scribe/decisions" ]
  [ -d "$PROJECT_DIR/.scribe/experiments" ]
  [ -f "$PROJECT_DIR/.scribe/lessons.md" ]
  [ -f "$PROJECT_DIR/.scribe/README.md" ]
  [ -f "$PROJECT_DIR/.scribe/overview.md" ]
  [ -f "$PROJECT_DIR/.scribe/preferences.md" ]
  [ -d "$PROJECT_DIR/.scribe/weekly" ]
  [ -d "$PROJECT_DIR/.scribe/artefacts" ]
}

@test "init fills in today's date in lessons.md" {
  "$SCRIBE_BIN" init
  grep -q "date: $(date '+%Y-%m-%d')" "$PROJECT_DIR/.scribe/lessons.md"
}

@test "init does not create or change CLAUDE.md or .gitignore" {
  make_git_repo
  "$SCRIBE_BIN" init
  [ ! -e "$PROJECT_DIR/CLAUDE.md" ]
  [ ! -e "$PROJECT_DIR/.gitignore" ]
}

@test "init keeps the journal out of git using .git/info/exclude" {
  make_git_repo
  "$SCRIBE_BIN" init
  grep -qx "/.scribe/" "$PROJECT_DIR/.git/info/exclude"
  touch "$PROJECT_DIR/.scribe/logbook/2026-01-01.md"
  [ -z "$(git -C "$PROJECT_DIR" status --porcelain)" ]
}

@test "init does not repeat the exclude line" {
  make_git_repo
  "$SCRIBE_BIN" init
  "$SCRIBE_BIN" init
  [ "$(grep -cx '/.scribe/' "$PROJECT_DIR/.git/info/exclude")" -eq 1 ]
}

@test "init works outside a git repository" {
  run "$SCRIBE_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$PROJECT_DIR/.scribe" ]
}

@test "init from a subfolder uses the git top level" {
  make_git_repo
  mkdir -p "$PROJECT_DIR/src/deep"
  cd "$PROJECT_DIR/src/deep"
  "$SCRIBE_BIN" init
  [ -d "$PROJECT_DIR/.scribe" ]
  [ ! -d "$PROJECT_DIR/src/deep/.scribe" ]
}

@test "init does not overwrite existing journal files" {
  "$SCRIBE_BIN" init
  echo "my own lessons" > "$PROJECT_DIR/.scribe/lessons.md"
  "$SCRIBE_BIN" init
  grep -q "my own lessons" "$PROJECT_DIR/.scribe/lessons.md"
}

@test "init refuses the home folder" {
  cd "$HOME"
  run "$SCRIBE_BIN" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"home folder"* ]]
}

@test "init mentions the background helper's cost when it is on" {
  run "$SCRIBE_BIN" init
  [[ "$output" == *"allowance"* ]]
}

@test "init --decline records the project outside it" {
  run "$SCRIBE_BIN" init --decline
  [ "$status" -eq 0 ]
  grep -qxF "$PROJECT_DIR" "$HOME/.scribe/declined"
  [ ! -e "$PROJECT_DIR/.scribe" ]
  [ ! -e "$PROJECT_DIR/.scribe-declined" ]
}

@test "init after a decline clears the decline" {
  "$SCRIBE_BIN" init --decline
  "$SCRIBE_BIN" init
  refute grep -qxF "$PROJECT_DIR" "$HOME/.scribe/declined"
}

@test "init refuses a project with an old journal/ folder" {
  mkdir -p "$PROJECT_DIR/journal"
  printf '<!-- scribe-block-begin -->\nx\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  run "$SCRIBE_BIN" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"migrate"* ]]
}
