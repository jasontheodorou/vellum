#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  install_fake_claude
  mkdir -p "$HOME/Desktop"
  "$VELLUM_BIN" init >/dev/null
  J="$PROJECT_DIR/.vellum"
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
  run "$VELLUM_BIN" archive
  [ "$status" -ne 0 ]
  [[ "$output" == *"nothing to archive"* ]] || false
}

@test "archive writes to the desktop and the library" {
  run "$VELLUM_BIN" archive
  [ "$status" -eq 0 ]
  [ -f "$ARCHIVE" ]
  cmp "$ARCHIVE" "$HOME/.vellum/library/test-project_archive.md"
}

@test "archive has every section and the summary from Claude" {
  "$VELLUM_BIN" archive
  grep -q "^## Summary" "$ARCHIVE"
  grep -q "Fake summary of the project." "$ARCHIVE"
  grep -q "^## Lessons learned" "$ARCHIVE"
  grep -q "Always measure first." "$ARCHIVE"
  grep -q "^## Decisions" "$ARCHIVE"
  grep -q "^## Recent activity" "$ARCHIVE"
  grep -q "^sessions: 1" "$ARCHIVE"
}

@test "archive turns entry headings into third-level headings" {
  "$VELLUM_BIN" archive
  grep -q "^### 001 Pick foo" "$ARCHIVE"
  grep -q "^### 2026-04-30" "$ARCHIVE"
  [ "$(grep -c '^# ' "$ARCHIVE")" -eq 1 ]
}

@test "archive strips frontmatter from entries" {
  "$VELLUM_BIN" archive
  refute grep -q "^id: decision-001-foo" "$ARCHIVE"
}

@test "archive gives Claude read-only tools and marks it as a helper" {
  "$VELLUM_BIN" archive
  grep -qx "Read,Glob,Grep" "$TEST_HOME/claude.args"
  grep -qx "dontAsk" "$TEST_HOME/claude.args"
  refute grep -q "bypassPermissions" "$TEST_HOME/claude.args"
  grep -qx "VELLUM_SUBAGENT=1" "$TEST_HOME/claude.env"
}

@test "archive passes the chosen model" {
  "$VELLUM_BIN" config model haiku
  "$VELLUM_BIN" archive
  grep -qx -- "--model" "$TEST_HOME/claude.args"
  grep -qx "haiku" "$TEST_HOME/claude.args"
}

@test "archive still works without claude" {
  rm -f "$FAKEBIN/claude"
  run "$VELLUM_BIN" archive
  [ "$status" -eq 0 ]
  grep -q "automatic summary was not available" "$ARCHIVE"
}

@test "archive handles file names with spaces" {
  echo "# Spaced" > "$J/decisions/002 with space.md"
  run "$VELLUM_BIN" archive
  [ "$status" -eq 0 ]
  grep -q "^### Spaced" "$ARCHIVE"
}

@test "archive includes the overview and preferences, under its own headings" {
  printf -- '---\nid: overview\n---\n# Overview\n\n## Where things stand\n\nTwo pages left.\n' > "$J/overview.md"
  printf '\n## Layout\n\n- One column only.\n' >> "$J/preferences.md"
  "$VELLUM_BIN" archive
  grep -q "^## Where it stands" "$ARCHIVE"
  grep -q "^### Where things stand" "$ARCHIVE"
  grep -q "Two pages left." "$ARCHIVE"
  grep -q "^## Preferences" "$ARCHIVE"
  grep -q "^### Layout" "$ARCHIVE"
}

@test "archive leaves out an overview that was never written" {
  "$VELLUM_BIN" archive
  refute grep -q "^## Where it stands" "$ARCHIVE"
}
