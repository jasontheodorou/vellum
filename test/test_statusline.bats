#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; P="$HOME/projects"; }
teardown() { teardown_isolated_env; }

line_for() {
  printf '{"cwd":"%s"}' "$1" | "$SCRIBE_BIN" statusline | sed 's/\x1b\[[0-9;]*m//g'
}

@test "statusline: just the name for a quiet project on main" {
  "$SCRIBE_BIN" new garden >/dev/null
  git -C "$P/garden" checkout -q -b main 2>/dev/null || true
  [ "$(line_for "$P/garden")" = "● garden" ]
}

@test "statusline: works from a subfolder" {
  "$SCRIBE_BIN" new garden >/dev/null
  mkdir -p "$P/garden/src/deep"
  [[ "$(line_for "$P/garden/src/deep")" == "● garden"* ]]
}

@test "statusline: shows a side branch" {
  "$SCRIBE_BIN" new garden >/dev/null
  git -C "$P/garden" checkout -q -b redesign
  [ "$(line_for "$P/garden")" = "● garden  redesign" ]
}

@test "statusline: shows a paused journal" {
  "$SCRIBE_BIN" new garden >/dev/null
  touch "$P/garden/.scribe/.paused"
  [[ "$(line_for "$P/garden")" == *"journal paused"* ]]
}

@test "statusline: nothing outside a project" {
  [ -z "$(line_for "$HOME")" ]
  mkdir -p "$HOME/Downloads"
  [ -z "$(line_for "$HOME/Downloads")" ]
}

@test "statusline: a kit folder that is not on the list still shows its name" {
  mkdir -p "$P/kitproj/design-journal"
  [ "$(line_for "$P/kitproj")" = "● kitproj" ]
}

@test "statusline: the same project always gets the same colour" {
  "$SCRIBE_BIN" new garden >/dev/null
  a=$(printf '{"cwd":"%s"}' "$P/garden" | "$SCRIBE_BIN" statusline)
  b=$(printf '{"cwd":"%s"}' "$P/garden" | "$SCRIBE_BIN" statusline)
  [ "$a" = "$b" ]
  [[ "$a" == *$'\033[38;5;'* ]]
}
