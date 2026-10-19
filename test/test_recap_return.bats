#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  P="$HOME/projects"
  "$VELLUM_BIN" new garden >/dev/null
  cat > "$P/garden/.vellum/overview.md" <<'MD'
# Overview

## Recent sessions

- 2026-10-16: Started the project and recorded the raised-beds decision.

## Next steps

- Confirm bed size and number.
MD
  TIMES="$HOME/.vellum/.state/prompts"
}
teardown() { teardown_isolated_env; }

start() {
  printf '{"cwd":"%s","source":"%s","session_id":"s1"}' "$P/garden" "${1:-startup}" |
    "$VELLUM_BIN" hook session-start >/dev/null
}

prompt() {
  printf '{"cwd":"%s","session_id":"s1","prompt":"hi"}' "${1:-$P/garden}" | "$VELLUM_BIN" hook prompt
}

away() { echo $(( $(date +%s) - $1 * 60 )) > "$TIMES/s1"; }

@test "return recap: none for prompts close together" {
  start
  run prompt
  [ -z "$output" ]
  run prompt
  [ -z "$output" ]
}

@test "return recap: shown once after an hour away" {
  start
  away 61
  run prompt
  [[ "$output" == *'"systemMessage"'*"Welcome back. Last time, 16 Oct: Started the project"*"Next: Confirm bed size"* ]] || false
  run prompt
  [ -z "$output" ]
}

@test "return recap: not after 59 minutes" {
  start
  away 59
  run prompt
  [ -z "$output" ]
}

@test "return recap: the break can be changed or turned off" {
  "$VELLUM_BIN" config recap-after 10 >/dev/null
  start
  away 11
  run prompt
  [[ "$output" == *"Welcome back."* ]] || false
  "$VELLUM_BIN" config recap-after off >/dev/null
  away 500
  run prompt
  [ -z "$output" ]
}

@test "return recap: config refuses words that are not minutes" {
  run "$VELLUM_BIN" config recap-after soon
  [ "$status" -ne 0 ]
}

@test "return recap: first prompt of a resumed conversation gets it" {
  start resume
  run prompt
  [[ "$output" == *"Welcome back."* ]] || false
}

@test "return recap: none when the session began before Vellum" {
  run prompt
  [ -z "$output" ]
  [ -f "$TIMES/s1" ]
}

@test "return recap: none for a paused project or the home folder" {
  start
  touch "$P/garden/.vellum/.paused"
  away 120
  run prompt
  [ -z "$output" ]
  away 120
  run prompt "$HOME"
  [ -z "$output" ]
}

@test "return recap: session end forgets the session's time" {
  start
  [ -f "$TIMES/s1" ]
  "$VELLUM_BIN" config background off >/dev/null
  printf '{"cwd":"%s","session_id":"s1","transcript_path":"/dev/null"}' "$P/garden" | "$VELLUM_BIN" hook session-end
  [ ! -f "$TIMES/s1" ]
}
