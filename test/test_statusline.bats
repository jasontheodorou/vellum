#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; P="$HOME/projects"; }
teardown() { teardown_isolated_env; }

line_for() {
  printf '{"cwd":"%s"}' "$1" | "$VELLUM_BIN" statusline | sed 's/\x1b\[[0-9;]*m//g'
}

@test "statusline: just the name for a quiet project on main" {
  "$VELLUM_BIN" new garden >/dev/null
  git -C "$P/garden" checkout -q -b main 2>/dev/null || true
  [ "$(line_for "$P/garden")" = "● garden" ]
}

@test "statusline: works from a subfolder" {
  "$VELLUM_BIN" new garden >/dev/null
  mkdir -p "$P/garden/src/deep"
  [[ "$(line_for "$P/garden/src/deep")" == "● garden"* ]] || false
}

@test "statusline: shows a side branch" {
  "$VELLUM_BIN" new garden >/dev/null
  git -C "$P/garden" checkout -q -b redesign
  [ "$(line_for "$P/garden")" = "● garden  redesign" ]
}

@test "statusline: shows a paused journal" {
  "$VELLUM_BIN" new garden >/dev/null
  touch "$P/garden/.vellum/.paused"
  [[ "$(line_for "$P/garden")" == *"journal paused"* ]] || false
}

@test "statusline: nothing outside a project" {
  [ -z "$(line_for "$HOME")" ]
  mkdir -p "$HOME/Downloads"
  [ -z "$(line_for "$HOME/Downloads")" ]
}

@test "statusline: a kit folder that is not on the list still shows its name" {
  mkdir -p "$P/kitproj/design-journal"
  [[ "$(line_for "$P/kitproj")" =~ ^.\ kitproj$ ]] || false
}

@test "statusline: the same project always gets the same colour" {
  "$VELLUM_BIN" new garden >/dev/null
  a=$(printf '{"cwd":"%s"}' "$P/garden" | "$VELLUM_BIN" statusline)
  b=$(printf '{"cwd":"%s"}' "$P/garden" | "$VELLUM_BIN" statusline)
  [ "$a" = "$b" ]
  [[ "$a" == $'\033[3'[1-6]m* ]] || false
}

@test "statusline: keeps the session's project when Claude looks elsewhere" {
  "$VELLUM_BIN" new garden >/dev/null
  mkdir -p "$HOME/elsewhere"
  printf '{"cwd":"%s","session_id":"s1"}' "$P/garden" | "$VELLUM_BIN" statusline >/dev/null
  out=$(printf '{"cwd":"%s","session_id":"s1"}' "$HOME/elsewhere" | "$VELLUM_BIN" statusline | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$out" == "● garden"* ]] || false
}

@test "statusline: each project keeps a different shape" {
  "$VELLUM_BIN" new one >/dev/null
  "$VELLUM_BIN" new two >/dev/null
  "$VELLUM_BIN" new three >/dev/null
  [ "$(line_for "$P/one")" = "● one" ]
  [ "$(line_for "$P/two")" = "◆ two" ]
  [ "$(line_for "$P/three")" = "▲ three" ]
  [ "$(line_for "$P/two")" = "◆ two" ]
}

@test "statusline: shapes are shared out evenly once all are used" {
  for i in $(seq 1 11); do "$VELLUM_BIN" new "p$i" >/dev/null; line_for "$P/p$i" >/dev/null; done
  [ "$(cut -f7 "$HOME/.vellum/projects.tsv" | LC_ALL=C sort | LC_ALL=C uniq -c | awk '$1 > 2' | wc -l | tr -d ' ')" -eq 0 ]
  [ "$(cut -f7 "$HOME/.vellum/projects.tsv" | LC_ALL=C sort -u | wc -l | tr -d ' ')" -eq 10 ]
}

@test "statusline: only the theme's own colours, and the name in plain bold" {
  "$VELLUM_BIN" new garden >/dev/null
  out=$(printf '{"cwd":"%s"}' "$P/garden" | "$VELLUM_BIN" statusline)
  refute grep -q '38;5;' <<<"$out"
  [[ "$out" == *$'\033[1mgarden\033[0m'* ]] || false
}

@test "statusline: no colour at all with NO_COLOR" {
  "$VELLUM_BIN" new garden >/dev/null
  out=$(printf '{"cwd":"%s"}' "$P/garden" | NO_COLOR=1 "$VELLUM_BIN" statusline)
  [ "$out" = "● garden" ]
}
