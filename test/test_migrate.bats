#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  make_git_repo
  mkdir -p "$PROJECT_DIR/journal/logbook" "$PROJECT_DIR/journal/.scribe.state.d"
  echo "old entry" > "$PROJECT_DIR/journal/logbook/2026-05-01.md"
  echo "foo" > "$PROJECT_DIR/journal/.imports.txt"
  printf '# My notes\n\n<!-- scribe-block-begin -->\n## Auto-journal\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  printf 'node_modules/\njournal/\n' > "$PROJECT_DIR/.gitignore"
}
teardown() { teardown_isolated_env; }

@test "migrate moves journal/ to .vellum/" {
  run "$VELLUM_BIN" migrate
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/journal" ]
  grep -q "old entry" "$PROJECT_DIR/.vellum/logbook/2026-05-01.md"
  grep -qx foo "$PROJECT_DIR/.vellum/.imports"
  [ ! -d "$PROJECT_DIR/.vellum/.scribe.state.d" ]
}

@test "migrate removes the block and keeps the rest of CLAUDE.md" {
  "$VELLUM_BIN" migrate
  grep -q "My notes" "$PROJECT_DIR/CLAUDE.md"
  refute grep -q "scribe-block" "$PROJECT_DIR/CLAUDE.md"
}

@test "migrate deletes a CLAUDE.md that only held the block" {
  printf '<!-- scribe-block-begin -->\nx\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  "$VELLUM_BIN" migrate
  [ ! -e "$PROJECT_DIR/CLAUDE.md" ]
}

@test "migrate swaps the .gitignore line for a local exclude" {
  "$VELLUM_BIN" migrate
  refute grep -qx "journal/" "$PROJECT_DIR/.gitignore"
  grep -qx "node_modules/" "$PROJECT_DIR/.gitignore"
  grep -qx "/.vellum/" "$PROJECT_DIR/.git/info/exclude"
}

@test "migrate refuses when .vellum/ already exists" {
  mkdir "$PROJECT_DIR/.vellum"
  run "$VELLUM_BIN" migrate
  [ "$status" -ne 0 ]
  [ -d "$PROJECT_DIR/journal" ]
}

@test "migrate refuses a project without an old journal" {
  rm -rf "$PROJECT_DIR/journal"
  run "$VELLUM_BIN" migrate
  [ "$status" -ne 0 ]
}
