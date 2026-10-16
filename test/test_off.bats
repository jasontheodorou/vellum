#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; make_git_repo; "$SCRIBE_BIN" init >/dev/null; }
teardown() { teardown_isolated_env; }

@test "off --yes deletes the journal and the exclude line" {
  run "$SCRIBE_BIN" off --yes
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/.scribe" ]
  refute grep -qx "/.scribe/" "$PROJECT_DIR/.git/info/exclude"
}

@test "off keeps other exclude lines" {
  echo "*.local" >> "$PROJECT_DIR/.git/info/exclude"
  "$SCRIBE_BIN" off --yes
  grep -qx "\*.local" "$PROJECT_DIR/.git/info/exclude"
}

@test "off without --yes stops on no" {
  run bash -c "echo n | '$SCRIBE_BIN' off"
  [ "$status" -ne 0 ]
  [ -d "$PROJECT_DIR/.scribe" ]
}

@test "off without --yes goes ahead on yes" {
  run bash -c "echo y | '$SCRIBE_BIN' off"
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/.scribe" ]
}
