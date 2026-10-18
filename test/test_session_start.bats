#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

start_hook() {
  hook_input SessionStart "" | "$VELLUM_BIN" hook session-start
}

@test "session-start: offers to add a git repository without a journal" {
  make_git_repo
  run start_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"not one of their projects yet"* ]] || false
  [[ "$output" == *"/bin/vellum\" adopt --session sess-1"* ]] || false
}

@test "session-start: does not offer for a folder that is not a project" {
  run start_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"not one of their projects yet"* ]] || false
}

@test "session-start: always explains the project commands, with the session id" {
  run start_hook
  [[ "$output" == *"Vellum runs this person"* ]] || false
  [[ "$output" == *"--session sess-1"* ]] || false
  [[ "$output" != *"{{"* ]] || false
}

@test "session-start: uses cwd from the hook input, not the shell's folder" {
  "$VELLUM_BIN" init >/dev/null
  cd /
  run start_hook
  [[ "$output" == *"The journal for this project is in"* ]] || false
}

@test "session-start: no offer after a decline" {
  make_git_repo
  "$VELLUM_BIN" init --decline
  run start_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"not one of their projects yet"* ]] || false
}

@test "session-start: honours the old .vellum-declined marker" {
  make_git_repo
  touch "$PROJECT_DIR/.vellum-declined"
  run start_hook
  [[ "$output" != *"not one of their projects yet"* ]] || false
}

@test "session-start: in the home folder, lists the projects" {
  "$VELLUM_BIN" new garden --about "A garden planner." >/dev/null
  PROJECT_DIR="$HOME" run start_hook
  [[ "$output" == *"Their projects, most recent first"* ]] || false
  [[ "$output" == *"garden"* ]] || false
  [[ "$output" == *"A garden planner."* ]] || false
  [[ "$output" != *"not one of their projects yet"* ]] || false
}

@test "session-start: paused notice" {
  "$VELLUM_BIN" init >/dev/null
  "$VELLUM_BIN" pause >/dev/null
  run start_hook
  [[ "$output" == *"paused"* ]] || false
  [[ "$output" != *"note things while the detail is fresh"* ]] || false
}

@test "session-start: active context has instructions, latest entry and lessons" {
  "$VELLUM_BIN" init >/dev/null
  printf -- '---\nid: x\n---\n# 2026-04-30\nLatest session content.\n' > "$PROJECT_DIR/.vellum/logbook/2026-04-30.md"
  printf '\n## Testing\n\n### Lesson: A lesson.\n' >> "$PROJECT_DIR/.vellum/lessons.md"
  run start_hook
  [[ "$output" == *"note things while the detail is fresh"* ]] || false
  [[ "$output" == *"Latest session content"* ]] || false
  [[ "$output" == *"A lesson."* ]] || false
  [[ "$output" == *'`logbook/2026-04-30.md`'* ]] || false
}

@test "session-start: fills in the full path to vellum" {
  "$VELLUM_BIN" init >/dev/null
  run start_hook
  [[ "$output" == *"$VELLUM_REPO/bin/vellum"* ]] || false
  [[ "$output" != *"{{VELLUM_BIN}}"* ]] || false
}

@test "session-start: cuts a very long logbook entry" {
  "$VELLUM_BIN" init >/dev/null
  seq 1 400 > "$PROJECT_DIR/.vellum/logbook/2026-04-30.md"
  run start_hook
  [[ "$output" == *"Cut at 150 of 400 lines"* ]] || false
  [[ "$output" != *$'\n'"300"$'\n'* ]] || false
}

@test "session-start: lists themed files" {
  "$VELLUM_BIN" init >/dev/null
  echo "# Bugs" > "$PROJECT_DIR/.vellum/bugs.md"
  run start_hook
  [[ "$output" == *'`bugs.md`'* ]] || false
}

@test "session-start: loads linked projects' summary and lessons only" {
  "$VELLUM_BIN" init >/dev/null
  mkdir -p "$HOME/.vellum/library"
  printf -- '---\nproject: foo\n---\n# foo\n\n## Summary\nFoo summary.\n\n## Lessons learned\n- Foo lesson.\n\n## Decisions\n### should not appear\n' > "$HOME/.vellum/library/foo_archive.md"
  "$VELLUM_BIN" link foo >/dev/null
  run start_hook
  [[ "$output" == *"Foo summary."* ]] || false
  [[ "$output" == *"Foo lesson."* ]] || false
  [[ "$output" != *"should not appear"* ]] || false
}

@test "session-start: offers to migrate an old journal" {
  mkdir -p "$PROJECT_DIR/journal"
  printf '<!-- scribe-block-begin -->\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  run start_hook
  [[ "$output" == *"/bin/vellum\" migrate"* ]] || false
}

@test "session-start: warns about a leftover old install" {
  mkdir -p "$HOME/.claude"
  echo '{"hooks":{"SessionStart":[{"scribe":true,"hooks":[{"command":"/u/.scribe/hooks/session-start.sh"}]}]}}' > "$HOME/.claude/settings.json"
  run start_hook
  [[ "$output" == *"remove-old-install"* ]] || false
}

@test "session-start: silent inside a helper session" {
  "$VELLUM_BIN" init >/dev/null
  VELLUM_SUBAGENT=1 run start_hook
  [ -z "$output" ]
  CLAUDE_JOURNAL_HOOK=1 run start_hook
  [ -z "$output" ]
}

@test "session-start: works without jq" {
  "$VELLUM_BIN" init >/dev/null
  mkdir -p "$TEST_HOME/nojq"
  for t in bash sh git sed awk grep head tail wc tr cat ls date dirname basename find mkdir rm mv cp touch seq sort; do
    p=$(command -v $t) && ln -sf "$p" "$TEST_HOME/nojq/$t"
  done
  cd /
  run bash -c "$(declare -f hook_input); PROJECT_DIR='$PROJECT_DIR' hook_input SessionStart '' | PATH='$TEST_HOME/nojq' '$VELLUM_BIN' hook session-start"
  [[ "$output" == *"The journal for this project is in"* ]] || false
}

@test "session-start: shows the overview once the curator has written it" {
  "$VELLUM_BIN" init >/dev/null
  printf -- '---\nid: overview\n---\n# Overview\n\n## What this is\n\nA calm life dashboard.\n' > "$PROJECT_DIR/.vellum/overview.md"
  printf -- '# 2026-04-30\nLOGBOOK BODY\n' > "$PROJECT_DIR/.vellum/logbook/2026-04-30.md"
  run start_hook
  [[ "$output" == *"A calm life dashboard."* ]] || false
  [[ "$output" != *"Most recent logbook entry"* ]] || false
}

@test "session-start: shows preferences and lesson titles, not lesson bodies" {
  "$VELLUM_BIN" init >/dev/null
  printf '\n## Layout\n\n- One column only (2026-10-03: "too busy").\n' >> "$PROJECT_DIR/.vellum/preferences.md"
  printf '\n## Testing\n\n### Lesson: lists that move under the pointer are unsafe\n\nLESSON BODY\n' >> "$PROJECT_DIR/.vellum/lessons.md"
  run start_hook
  [[ "$output" == *"One column only"* ]] || false
  [[ "$output" == *"### Lesson: lists that move under the pointer are unsafe"* ]] || false
  [[ "$output" != *"LESSON BODY"* ]] || false
}

@test "session-start: adds new starter files to an older journal" {
  "$VELLUM_BIN" init >/dev/null
  rm -f "$PROJECT_DIR/.vellum/preferences.md" "$PROJECT_DIR/.vellum/overview.md"
  rm -rf "$PROJECT_DIR/.vellum/weekly"
  echo "kept" > "$PROJECT_DIR/.vellum/lessons.md"
  start_hook >/dev/null
  [ -f "$PROJECT_DIR/.vellum/preferences.md" ]
  [ -f "$PROJECT_DIR/.vellum/overview.md" ]
  [ -d "$PROJECT_DIR/.vellum/weekly" ]
  grep -qx kept "$PROJECT_DIR/.vellum/lessons.md"
}
