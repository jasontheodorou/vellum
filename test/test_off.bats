#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; make_git_repo; "$VELLUM_BIN" init >/dev/null; }
teardown() { teardown_isolated_env; }

@test "off --yes deletes the journal and the exclude line" {
  run "$VELLUM_BIN" off --yes
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/.vellum" ]
  refute grep -qx "/.vellum/" "$PROJECT_DIR/.git/info/exclude"
}

@test "off keeps other exclude lines" {
  echo "*.local" >> "$PROJECT_DIR/.git/info/exclude"
  "$VELLUM_BIN" off --yes
  grep -qx "\*.local" "$PROJECT_DIR/.git/info/exclude"
}

@test "off without --yes stops on no" {
  run bash -c "echo n | '$VELLUM_BIN' off"
  [ "$status" -ne 0 ]
  [ -d "$PROJECT_DIR/.vellum" ]
}

@test "off without --yes goes ahead on yes" {
  run bash -c "echo y | '$VELLUM_BIN' off"
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/.vellum" ]
}
