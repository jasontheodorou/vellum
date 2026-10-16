#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  install_fake_claude
  mkdir -p "$HOME/Desktop"
  "$SCRIBE_BIN" init >/dev/null
  J="$PROJECT_DIR/.scribe"
  cat >"$J/logbook/2026-04-30.md" <<EOF2
---
id: log-2026-04-30
type: logbook
---
# 2026-04-30
First session content.
EOF2
  cat >"$J/decisions/001-foo.md" <<EOF2
---
id: decision-001-foo
type: decision
---
# 001 Pick foo
Decided to pick foo.
EOF2
  echo "- Always measure first." >> "$J/lessons.md"
  ARCHIVE="$HOME/Desktop/test-project_archive.md"
}
teardown() { teardown_isolated_env; }

@test "archive refuses an empty journal" {
  rm -f "$J"/logbook/*.md "$J"/decisions/*.md "$J/lessons.md"
  run "$SCRIBE_BIN" archive
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to archive"* ]]
}

@test "archive writes to the desktop and the library" {
  run "$SCRIBE_BIN" archive
  [ "$status" -eq 0 ]
  [ -f "$ARCHIVE" ]
  cmp "$ARCHIVE" "$HOME/.scribe/library/test-project_archive.md"
}

@test "archive has every section and the summary from Claude" {
  "$SCRIBE_BIN" archive
  grep -q "^## Summary" "$ARCHIVE"
  grep -q "Fake summary of the project." "$ARCHIVE"
  grep -q "^## Lessons learned" "$ARCHIVE"
  grep -q "Always measure first." "$ARCHIVE"
  grep -q "^## Decisions" "$ARCHIVE"
  grep -q "^## Recent activity" "$ARCHIVE"
  grep -q "^sessions: 1" "$ARCHIVE"
}

@test "archive turns entry headings into third-level headings" {
  "$SCRIBE_BIN" archive
  grep -q "^### 001 Pick foo" "$ARCHIVE"
  grep -q "^### 2026-04-30" "$ARCHIVE"
  [ "$(grep -c '^# ' "$ARCHIVE")" -eq 1 ]
}

@test "archive strips frontmatter from entries" {
  "$SCRIBE_BIN" archive
  refute grep -q "^id: decision-001-foo" "$ARCHIVE"
}

@test "archive gives Claude read-only tools and marks it as a helper" {
  "$SCRIBE_BIN" archive
  grep -qx "Read,Glob,Grep" "$TEST_HOME/claude.args"
  grep -qx "dontAsk" "$TEST_HOME/claude.args"
  refute grep -q "bypassPermissions" "$TEST_HOME/claude.args"
  grep -qx "SCRIBE_SUBAGENT=1" "$TEST_HOME/claude.env"
}

@test "archive passes the chosen model" {
  "$SCRIBE_BIN" config model haiku
  "$SCRIBE_BIN" archive
  grep -qx -- "--model" "$TEST_HOME/claude.args"
  grep -qx "haiku" "$TEST_HOME/claude.args"
}

@test "archive still works without claude" {
  rm -f "$FAKEBIN/claude"
  run "$SCRIBE_BIN" archive
  [ "$status" -eq 0 ]
  grep -q "automatic summary was not available" "$ARCHIVE"
}

@test "archive handles file names with spaces" {
  echo "# Spaced" > "$J/decisions/002 with space.md"
  run "$SCRIBE_BIN" archive
  [ "$status" -eq 0 ]
  grep -q "^### Spaced" "$ARCHIVE"
}
