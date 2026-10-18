#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  "$VELLUM_BIN" init >/dev/null
  mkdir -p "$HOME/.vellum/library"
  cat >"$HOME/.vellum/library/foo_archive.md" <<ARCH
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
  run "$VELLUM_BIN" link foo
  [ "$status" -eq 0 ]
  grep -qx "foo" "$PROJECT_DIR/.vellum/.imports"
}

@test "link does not repeat itself" {
  "$VELLUM_BIN" link foo
  "$VELLUM_BIN" link foo
  [ "$(grep -cx foo "$PROJECT_DIR/.vellum/.imports")" -eq 1 ]
}

@test "link rejects a project that is not in the library" {
  run "$VELLUM_BIN" link nope
  [ "$status" -ne 0 ]
  [[ "$output" == *"not on the project list or in the library"* ]] || false
}

@test "unlink removes the entry" {
  "$VELLUM_BIN" link foo
  run "$VELLUM_BIN" unlink foo
  [ "$status" -eq 0 ]
  [ ! -f "$PROJECT_DIR/.vellum/.imports" ]
}

@test "library lists archived projects with their dates" {
  run "$VELLUM_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"foo (archived 2026-04-01)"* ]] || false
}

@test "library when empty says so" {
  rm -f "$HOME/.vellum/library"/*.md
  run "$VELLUM_BIN" library
  [ "$status" -eq 0 ]
  [[ "$output" == *"no archived projects"* ]] || false
}
