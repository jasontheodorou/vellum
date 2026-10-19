#!/usr/bin/env bats
# Vellum was called Scribe. Its data moves from ~/.scribe to ~/.vellum, and
# each project's .scribe/ journal moves to .vellum/.

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "moves Scribe's data to ~/.vellum the first time it runs" {
  mkdir -p "$HOME/.scribe/library" "$HOME/.scribe/sessions"
  echo "keep me" > "$HOME/.scribe/library/archive.md"
  printf 'garden\t/x\t3001\tactive\t2026-10-01\t\n' > "$HOME/.scribe/projects.tsv"
  echo "old line" > "$HOME/.scribe/scribe.log"
  run "$VELLUM_BIN" version
  [ "$status" -eq 0 ]
  grep -q "keep me" "$HOME/.vellum/library/archive.md"
  grep -q garden "$HOME/.vellum/projects.tsv"
  grep -q "old line" "$HOME/.vellum/vellum.log"
  [ ! -d "$HOME/.scribe" ]
}

@test "leaves the old curl install's files for remove-old-install" {
  mkdir -p "$HOME/.scribe/hooks" "$HOME/.scribe/library"
  "$VELLUM_BIN" version
  [ -d "$HOME/.scribe/hooks" ]
  [ -d "$HOME/.vellum/library" ]
}

@test "never overwrites data already in ~/.vellum" {
  mkdir -p "$HOME/.scribe" "$HOME/.vellum"
  echo old > "$HOME/.scribe/config"
  echo new > "$HOME/.vellum/config"
  "$VELLUM_BIN" version
  grep -qx new "$HOME/.vellum/config"
  grep -qx old "$HOME/.scribe/config"
}

@test "moves only once" {
  mkdir -p "$HOME/.scribe/hooks"
  "$VELLUM_BIN" version
  mkdir -p "$HOME/.scribe/library"
  "$VELLUM_BIN" version
  [ -d "$HOME/.scribe/library" ]
}

@test "renames a project's .scribe/ journal to .vellum/" {
  make_git_repo
  mkdir -p "$PROJECT_DIR/.scribe/logbook"
  echo "# Overview" > "$PROJECT_DIR/.scribe/overview.md"
  echo "/.scribe/" >> "$PROJECT_DIR/.git/info/exclude"
  run "$VELLUM_BIN" status
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.vellum/overview.md" ]
  [ ! -e "$PROJECT_DIR/.scribe" ]
  grep -qx "/.vellum/" "$PROJECT_DIR/.git/info/exclude"
  refute grep -qx "/.scribe/" "$PROJECT_DIR/.git/info/exclude"
}

@test "leaves a .scribe folder alone when it is not a journal" {
  mkdir -p "$PROJECT_DIR/.scribe"
  echo x > "$PROJECT_DIR/.scribe/other"
  "$VELLUM_BIN" status || true
  [ -f "$PROJECT_DIR/.scribe/other" ]
}

@test "still respects a 'no' given to Scribe" {
  touch "$PROJECT_DIR/.scribe-declined"
  run "$VELLUM_BIN" hook session-start < <(hook_input SessionStart /dev/null)
  refute grep -q "ask once whether to add it" <<<"$output"
}

@test "tries the move again when an earlier one was cut short" {
  mkdir -p "$HOME/.scribe/library" "$HOME/.vellum/.moving"
  echo "keep me" > "$HOME/.scribe/library/archive.md"
  touch -t 202001010000 "$HOME/.vellum/.moving"
  "$VELLUM_BIN" version
  grep -q "keep me" "$HOME/.vellum/library/archive.md"
  [ -f "$HOME/.vellum/.moved-from-scribe" ]
}

@test "waits while another move is still running" {
  mkdir -p "$HOME/.scribe/library" "$HOME/.vellum/.moving"
  echo "keep me" > "$HOME/.scribe/library/archive.md"
  "$VELLUM_BIN" version
  [ -f "$HOME/.scribe/library/archive.md" ]
  [ ! -f "$HOME/.vellum/.moved-from-scribe" ]
}
