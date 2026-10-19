#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "curator prompt: & and backslashes in a project name come through unchanged" {
  install_fake_claude
  mkdir -p "$TEST_HOME/R&D\\x"
  cd "$TEST_HOME/R&D\\x"
  "$VELLUM_BIN" init >/dev/null
  "$VELLUM_BIN" curate >/dev/null
  grep -qF 'journal for "R&D\x"' "$TEST_HOME/claude.stdin"
  refute grep -q "{{" "$TEST_HOME/claude.stdin"
}

@test "init refuses the projects folder itself" {
  mkdir -p "$HOME/projects"
  cd "$HOME/projects"
  run "$VELLUM_BIN" init
  [ "$status" -ne 0 ]
  [[ "$output" == *"projects folder"* ]] || false
  [ ! -d "$HOME/projects/.vellum" ]
}

@test "init and status call the end-of-session helper the curator" {
  run "$VELLUM_BIN" init
  [[ "$output" == *"curator"* ]] || false
  [[ "$output" != *"helper"* ]] || false
  run "$VELLUM_BIN" status
  [[ "$output" == *"curator:"* ]] || false
}

@test "resume prints the journal for Claude when the project context is available" {
  "$VELLUM_BIN" init >/dev/null
  "$VELLUM_BIN" pause >/dev/null
  run "$VELLUM_BIN" resume
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Journaling resumed." ]] || false
  if grep -q '^print_project_context()' "$VELLUM_REPO/lib/hooks.sh"; then
    [[ "$output" == *"Journal for test-project"* ]] || false
  fi
}

@test "off --yes refuses a journal that is tracked by git" {
  make_git_repo
  mkdir -p "$PROJECT_DIR/design-journal"
  "$VELLUM_BIN" init >/dev/null
  git -C "$PROJECT_DIR" add design-journal
  run "$VELLUM_BIN" off --yes
  [ "$status" -ne 0 ]
  [[ "$output" == *"tracked by git"* ]] || false
  [ -d "$PROJECT_DIR/design-journal" ]
  run "$VELLUM_BIN" off --yes --delete-tracked
  [ "$status" -eq 0 ]
  [ ! -d "$PROJECT_DIR/design-journal" ]
}

@test "off asks about a tracked journal and says it is tracked" {
  make_git_repo
  mkdir -p "$PROJECT_DIR/design-journal"
  "$VELLUM_BIN" init >/dev/null
  git -C "$PROJECT_DIR" add design-journal
  run bash -c "echo n | '$VELLUM_BIN' off"
  [ "$status" -ne 0 ]
  [[ "$output" == *"tracked by git"* ]] || false
  [ -d "$PROJECT_DIR/design-journal" ]
}

@test "doctor: notes the theme, status line and font without failing" {
  install_fake_claude
  run "$VELLUM_BIN" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"note Claude Code's theme is not light-ansi"* ]] || false
  [[ "$output" == *"note the status line is not Vellum's"* ]] || false
  [[ "$output" == *"note Paper Mono is not installed"* ]] || false
  [[ "$output" == *"curator after each session"* ]] || false
}

@test "doctor: sees the theme, status line and font when they are set up" {
  install_fake_claude
  mkdir -p "$TEST_HOME/cfg" "$HOME/Library/Fonts"
  touch "$HOME/Library/Fonts/PaperMono-Regular.otf"
  printf '{\n  "theme": "light-ansi",\n  "statusLine": {"type": "command", "command": "%s/.vellum/bin/vellum statusline"}\n}\n' "$HOME" >"$TEST_HOME/cfg/settings.json"
  CLAUDE_CONFIG_DIR="$TEST_HOME/cfg" run "$VELLUM_BIN" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok   Claude Code uses the Terminal's colours"* ]] || false
  [[ "$output" == *"ok   the status line is Vellum's"* ]] || false
  [[ "$output" == *"ok   Paper Mono is installed"* ]] || false
}
