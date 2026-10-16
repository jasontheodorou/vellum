#!/usr/bin/env bash
# Shared test helpers. Each test runs in a throwaway $HOME, so the real
# ~/.scribe and ~/.claude are never touched.

SCRIBE_REPO="${SCRIBE_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SCRIBE_BIN="$SCRIBE_REPO/bin/scribe"

setup_isolated_env() {
  TEST_HOME="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/scribe-test.XXXXXX")" && pwd)"
  export HOME="$TEST_HOME" TEST_HOME
  unset SCRIBE_HOME SCRIBE_SUBAGENT CLAUDE_JOURNAL_HOOK CLAUDE_PROJECT_DIR
  export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

  PROJECT_DIR="$TEST_HOME/test-project"
  mkdir -p "$PROJECT_DIR"
  export PROJECT_DIR SCRIBE_BIN

  # Keep the real claude off PATH unless a test installs the fake one.
  FAKEBIN="$TEST_HOME/fakebin"
  mkdir -p "$FAKEBIN"
  export PATH="$FAKEBIN:/usr/bin:/bin:/usr/sbin:/sbin"
  cd "$PROJECT_DIR" || return 1
}

teardown_isolated_env() {
  if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
    rm -rf "$TEST_HOME"
  fi
}

make_git_repo() {
  git -C "$PROJECT_DIR" init -q
}

# A fake `claude` that records its arguments and stdin, and prints a summary.
install_fake_claude() {
  cat >"$FAKEBIN/claude" <<'FAKE'
#!/bin/bash
printf '%s\n' "$@" >> "$TEST_HOME/claude.args"
cat >> "$TEST_HOME/claude.stdin"
echo "SCRIBE_SUBAGENT=${SCRIBE_SUBAGENT:-}" >> "$TEST_HOME/claude.env"
echo "Fake summary of the project."
FAKE
  chmod +x "$FAKEBIN/claude"
}

install_fake_xdg() {
  cat >"$FAKEBIN/xdg-user-dir" <<'FAKE'
#!/bin/bash
echo "$TEST_HOME/xdg-desktop"
FAKE
  chmod +x "$FAKEBIN/xdg-user-dir"
  mkdir -p "$TEST_HOME/xdg-desktop"
}

# Wait up to two seconds for a file to appear (the session-end helper runs in the background).
wait_for_file() {
  local _
  for _ in $(seq 1 50); do
    [ -f "$1" ] && return 0
    sleep 0.1
  done
  return 1
}

hook_input() {
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"%s"}' \
    "${3:-sess-1}" "$2" "$PROJECT_DIR" "$1"
}

# Fails when the command succeeds. Bats ignores a bare `! cmd` that is not the
# last line of a test, so use this instead.
refute() {
  if "$@"; then
    echo "expected this to fail: $*" >&2
    return 1
  fi
}
