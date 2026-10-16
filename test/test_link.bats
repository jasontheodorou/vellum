#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$SCRIBE_BIN" init >/dev/null
  mkdir -p "$HOME/.scribe/library"
  cat >"$HOME/.scribe/library/foo_archive.md" <<ARCH
---
project: foo
archived: 2026-04-01
---
# foo

## Summary
Foo summary content.

## Lessons learned
- Foo lesson.
ARCH
}
teardown() { teardown_isolated_env; }

@test "link records the project" {
  run "$SCRIBE_BIN" link foo
  [ "$status" -eq 0 ]
  grep -qx "foo" "$PROJECT_DIR/.scribe/.imports"
}

@test "link does not repeat itself" {
  "$SCRIBE_BIN" link foo
  "$SCRIBE_BIN" link foo
  [ "$(grep -cx foo "$PROJECT_DIR/.scribe/.imports")" -eq 1 ]
}

@test "link rejects a project that is not in the library" {
  run "$SCRIBE_BIN" link nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"not found in library"* ]]
}

@test "unlink removes the entry" {
  "$SCRIBE_BIN" link foo
  run "$SCRIBE_BIN" unlink foo
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.scribe/.imports" ]
}

@test "library lists archived projects with their dates" {
  run "$SCRIBE_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo (archived 2026-04-01)"* ]]
}

@test "library when empty says so" {
  rm -f "$HOME/.scribe/library"/*.md
  run "$SCRIBE_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"no archived projects"* ]]
}
