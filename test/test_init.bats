#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "init creates the .vellum journal" {
  run "$VELLUM_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$PROJECT_DIR/.vellum/logbook" ]
  [ -d "$PROJECT_DIR/.vellum/decisions" ]
  [ -d "$PROJECT_DIR/.vellum/experiments" ]
  [ -f "$PROJECT_DIR/.vellum/lessons.md" ]
  [ -f "$PROJECT_DIR/.vellum/README.md" ]
  [ -f "$PROJECT_DIR/.vellum/overview.md" ]
  [ -f "$PROJECT_DIR/.vellum/preferences.md" ]
  [ -d "$PROJECT_DIR/.vellum/weekly" ]
  [ -d "$PROJECT_DIR/.vellum/artefacts" ]
}

@test "init fills in today's date in lessons.md" {
  "$VELLUM_BIN" init
  grep -q "date: $(date '+%Y-%m-%d')" "$PROJECT_DIR/.vellum/lessons.md"
}

@test "init does not create or change CLAUDE.md or .gitignore" {
  make_git_repo
  "$VELLUM_BIN" init
  [ ! -e "$PROJECT_DIR/CLAUDE.md" ]
  [ ! -e "$PROJECT_DIR/.gitignore" ]
}

@test "init keeps the journal out of git using .git/info/exclude" {
  make_git_repo
  "$VELLUM_BIN" init
  grep -qx "/.vellum/" "$PROJECT_DIR/.git/info/exclude"
  touch "$PROJECT_DIR/.vellum/logbook/2026-01-01.md"
  [ -z "$(git -C "$PROJECT_DIR" status --porcelain)" ]
}

@test "init does not repeat the exclude line" {
  make_git_repo
  "$VELLUM_BIN" init
  "$VELLUM_BIN" init
  [ "$(grep -cx '/.vellum/' "$PROJECT_DIR/.git/info/exclude")" -eq 1 ]
}

@test "init works outside a git repository" {
  run "$VELLUM_BIN" init
  [ "$status" -eq 0 ]
  [ -d "$PROJECT_DIR/.vellum" ]
}

@test "init from a subfolder uses the git top level" {
  make_git_repo
  mkdir -p "$PROJECT_DIR/src/deep"
  cd "$PROJECT_DIR/src/deep"
  "$VELLUM_BIN" init
  [ -d "$PROJECT_DIR/.vellum" ]
  [ ! -d "$PROJECT_DIR/src/deep/.vellum" ]
}

@test "init does not overwrite existing journal files" {
  "$VELLUM_BIN" init
  echo "my own lessons" > "$PROJECT_DIR/.vellum/lessons.md"
  "$VELLUM_BIN" init
  grep -q "my own lessons" "$PROJECT_DIR/.vellum/lessons.md"
}

@test "init refuses the home folder" {
  cd "$HOME"
  run "$VELLUM_BIN" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"home folder"* ]] || false
}

@test "init mentions the background helper's cost when it is on" {
  run "$VELLUM_BIN" init
  [[ "$output" == *"allowance"* ]] || false
}

@test "init --decline records the project outside it" {
  run "$VELLUM_BIN" init --decline
  [ "$status" -eq 0 ]
  grep -qxF "$PROJECT_DIR" "$HOME/.vellum/declined"
  [ ! -e "$PROJECT_DIR/.vellum" ]
  [ ! -e "$PROJECT_DIR/.vellum-declined" ]
}

@test "init after a decline clears the decline" {
  "$VELLUM_BIN" init --decline
  "$VELLUM_BIN" init
  refute grep -qxF "$PROJECT_DIR" "$HOME/.vellum/declined"
}

@test "init refuses a project with an old journal/ folder" {
  mkdir -p "$PROJECT_DIR/journal"
  printf '<!-- scribe-block-begin -->\nx\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  run "$VELLUM_BIN" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"migrate"* ]] || false
}
