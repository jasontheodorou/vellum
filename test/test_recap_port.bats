#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  P="$HOME/projects"
  "$VELLUM_BIN" new garden >/dev/null
  cat > "$P/garden/.vellum/overview.md" <<'MD'
---
id: overview
---
# Overview

## What this is

A garden planner.

## Recent sessions

- 2026-10-16: Started the project, wrote plan.md and recorded the raised-beds decision.
- 2026-10-15: Earlier work.

## Next steps

- Confirm bed size and number.
MD
}
teardown() { teardown_isolated_env; }

message_for() {
  printf '{"cwd":"%s","source":"%s","session_id":"s"}' "$1" "${2:-startup}" | "$VELLUM_BIN" hook session-start |
    python3 -c 'import json,sys; d=sys.stdin.read(); print(json.loads(d)["systemMessage"] if d.startswith("{") else "")'
}

@test "recap: last time and next, from the curated overview" {
  [ "$(message_for "$P/garden")" = "Last time, 16 Oct: Started the project, wrote plan.md and recorded the raised-beds decision. Next: Confirm bed size and number." ]
}

@test "recap: not shown after /clear or when the context is compacted" {
  [ -z "$(message_for "$P/garden" clear)" ]
  [ -z "$(message_for "$P/garden" compact)" ]
}

@test "recap: not shown in the home folder, or for a paused journal" {
  [ -z "$(message_for "$HOME")" ]
  touch "$P/garden/.vellum/.paused"
  [ -z "$(message_for "$P/garden")" ]
}

@test "recap: falls back to the latest logbook's first sentence" {
  "$VELLUM_BIN" new plain >/dev/null
  printf '# 2026-10-01\n\nWe chose a ten-column grid. Then other things happened.\n' > "$P/plain/.vellum/logbook/2026-10-01.md"
  [ "$(message_for "$P/plain")" = "Last time, 1 Oct: We chose a ten-column grid." ]
}

@test "recap: nothing for a brand new journal" {
  "$VELLUM_BIN" new fresh >/dev/null
  [ -z "$(message_for "$P/fresh")" ]
}

@test "recap: sits above the curator's message when both are waiting" {
  mkdir -p "$HOME/.vellum/notices"
  echo "Journal updated after your last session: garden, 1 decision." > "$HOME/.vellum/notices/$("$VELLUM_BIN" __sanitize "$P/garden")"
  msg="$(message_for "$P/garden")"
  [[ "$msg" == "Last time, 16 Oct:"*$'\n'"Journal updated after your last session: garden, 1 decision." ]] || false
}

@test "port: Claude is told the project's port" {
  out=$(printf '{"cwd":"%s","session_id":"s"}' "$P/garden" | "$VELLUM_BIN" hook session-start)
  [[ "$out" == *"This project's port is 3001"* ]] || false
  [[ "$out" == *"PORT=3001 npm run dev"* ]] || false
  run "$VELLUM_BIN" open garden
  [[ "$output" == *"This project's port is 3001"* ]] || false
}

@test "port: commands in the session get PORT set" {
  export CLAUDE_ENV_FILE="$TEST_HOME/env"
  printf '{"cwd":"%s","session_id":"s"}' "$P/garden" | "$VELLUM_BIN" hook session-start >/dev/null
  grep -qx "export PORT=3001" "$CLAUDE_ENV_FILE"
}

@test "port: no PORT outside a project" {
  export CLAUDE_ENV_FILE="$TEST_HOME/env"
  printf '{"cwd":"%s","session_id":"s"}' "$HOME" | "$VELLUM_BIN" hook session-start >/dev/null
  [ ! -s "$CLAUDE_ENV_FILE" ]
}
