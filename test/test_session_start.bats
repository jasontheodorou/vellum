#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

start_hook() {
  hook_input SessionStart "" | "$SCRIBE_BIN" hook session-start
}

@test "session-start: offers to add a git repository without a journal" {
  make_git_repo
  run start_hook
  [ "$status" -eq 0 ]
  [[ "$output" == *"not one of their projects yet"* ]]
  [[ "$output" == *"/bin/scribe\" adopt --session sess-1"* ]]
}

@test "session-start: does not offer for a folder that is not a project" {
  run start_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"not one of their projects yet"* ]]
}

@test "session-start: always explains the project commands, with the session id" {
  run start_hook
  [[ "$output" == *"Scribe runs this person"* ]]
  [[ "$output" == *"--session sess-1"* ]]
  [[ "$output" != *"{{"* ]]
}

@test "session-start: uses cwd from the hook input, not the shell's folder" {
  "$SCRIBE_BIN" init >/dev/null
  cd /
  run start_hook
  [[ "$output" == *"The journal for this project is in"* ]]
}

@test "session-start: no offer after a decline" {
  make_git_repo
  "$SCRIBE_BIN" init --decline
  run start_hook
  [ "$status" -eq 0 ]
  [[ "$output" != *"not one of their projects yet"* ]]
}

@test "session-start: honours the old .scribe-declined marker" {
  make_git_repo
  touch "$PROJECT_DIR/.scribe-declined"
  run start_hook
  [[ "$output" != *"not one of their projects yet"* ]]
}

@test "session-start: in the home folder, lists the projects" {
  "$SCRIBE_BIN" new garden --about "A garden planner." >/dev/null
  PROJECT_DIR="$HOME" run start_hook
  [[ "$output" == *"Their projects, most recent first"* ]]
  [[ "$output" == *"garden"* ]]
  [[ "$output" == *"A garden planner."* ]]
  [[ "$output" != *"not one of their projects yet"* ]]
}

@test "session-start: paused notice" {
  "$SCRIBE_BIN" init >/dev/null
  "$SCRIBE_BIN" pause >/dev/null
  run start_hook
  [[ "$output" == *"paused"* ]]
  [[ "$output" != *"note things while the detail is fresh"* ]]
}

@test "session-start: active context has instructions, latest entry and lessons" {
  "$SCRIBE_BIN" init >/dev/null
  printf -- '---\nid: x\n---\n# 2026-04-30\nLatest session content.\n' > "$PROJECT_DIR/.scribe/logbook/2026-04-30.md"
  echo "- A lesson." >> "$PROJECT_DIR/.scribe/lessons.md"
  run start_hook
  [[ "$output" == *"note things while the detail is fresh"* ]]
  [[ "$output" == *"Latest session content"* ]]
  [[ "$output" == *"A lesson."* ]]
  [[ "$output" == *'`logbook/2026-04-30.md`'* ]]
}

@test "session-start: fills in the full path to scribe" {
  "$SCRIBE_BIN" init >/dev/null
  run start_hook
  [[ "$output" == *"$SCRIBE_REPO/bin/scribe"* ]]
  [[ "$output" != *"{{SCRIBE_BIN}}"* ]]
}

@test "session-start: cuts a very long logbook entry" {
  "$SCRIBE_BIN" init >/dev/null
  seq 1 400 > "$PROJECT_DIR/.scribe/logbook/2026-04-30.md"
  run start_hook
  [[ "$output" == *"Cut at 150 of 400 lines"* ]]
  [[ "$output" != *$'\n'"300"$'\n'* ]]
}

@test "session-start: lists themed files" {
  "$SCRIBE_BIN" init >/dev/null
  echo "# Bugs" > "$PROJECT_DIR/.scribe/bugs.md"
  run start_hook
  [[ "$output" == *'`bugs.md`'* ]]
}

@test "session-start: loads linked projects' summary and lessons only" {
  "$SCRIBE_BIN" init >/dev/null
  mkdir -p "$HOME/.scribe/library"
  printf -- '---\nproject: foo\n---\n# foo\n\n## Summary\nFoo summary.\n\n## Lessons learned\n- Foo lesson.\n\n## Decisions\n### should not appear\n' > "$HOME/.scribe/library/foo_archive.md"
  "$SCRIBE_BIN" link foo >/dev/null
  run start_hook
  [[ "$output" == *"Foo summary."* ]]
  [[ "$output" == *"Foo lesson."* ]]
  [[ "$output" != *"should not appear"* ]]
}

@test "session-start: offers to migrate an old journal" {
  mkdir -p "$PROJECT_DIR/journal"
  printf '<!-- scribe-block-begin -->\n<!-- scribe-block-end -->\n' > "$PROJECT_DIR/CLAUDE.md"
  run start_hook
  [[ "$output" == *"/bin/scribe\" migrate"* ]]
}

@test "session-start: warns about a leftover old install" {
  mkdir -p "$HOME/.claude"
  echo '{"hooks":{"SessionStart":[{"scribe":true,"hooks":[{"command":"/u/.scribe/hooks/session-start.sh"}]}]}}' > "$HOME/.claude/settings.json"
  run start_hook
  [[ "$output" == *"remove-old-install"* ]]
}

@test "session-start: silent inside a helper session" {
  "$SCRIBE_BIN" init >/dev/null
  SCRIBE_SUBAGENT=1 run start_hook
  [ -z "$output" ]
  CLAUDE_JOURNAL_HOOK=1 run start_hook
  [ -z "$output" ]
}

@test "session-start: works without jq" {
  "$SCRIBE_BIN" init >/dev/null
  mkdir -p "$TEST_HOME/nojq"
  for t in bash sh git sed awk grep head tail wc tr cat ls date dirname basename find mkdir rm mv cp touch seq sort; do
    p=$(command -v $t) && ln -sf "$p" "$TEST_HOME/nojq/$t"
  done
  cd /
  run bash -c "$(declare -f hook_input); PROJECT_DIR='$PROJECT_DIR' hook_input SessionStart '' | PATH='$TEST_HOME/nojq' '$SCRIBE_BIN' hook session-start"
  [[ "$output" == *"The journal for this project is in"* ]]
}

@test "session-start: shows the overview once the curator has written it" {
  "$SCRIBE_BIN" init >/dev/null
  printf -- '---\nid: overview\n---\n# Overview\n\n## What this is\n\nA calm life dashboard.\n' > "$PROJECT_DIR/.scribe/overview.md"
  printf -- '# 2026-04-30\nLOGBOOK BODY\n' > "$PROJECT_DIR/.scribe/logbook/2026-04-30.md"
  run start_hook
  [[ "$output" == *"A calm life dashboard."* ]]
  [[ "$output" != *"Most recent logbook entry"* ]]
}

@test "session-start: shows preferences and lesson titles, not lesson bodies" {
  "$SCRIBE_BIN" init >/dev/null
  printf '\n## Layout\n\n- One column only (2026-10-03: "too busy").\n' >> "$PROJECT_DIR/.scribe/preferences.md"
  printf '\n## Testing\n\n### Lesson: lists that move under the pointer are unsafe\n\nLESSON BODY\n' >> "$PROJECT_DIR/.scribe/lessons.md"
  run start_hook
  [[ "$output" == *"One column only"* ]]
  [[ "$output" == *"### Lesson: lists that move under the pointer are unsafe"* ]]
  [[ "$output" != *"LESSON BODY"* ]]
}

@test "session-start: adds new starter files to an older journal" {
  "$SCRIBE_BIN" init >/dev/null
  rm -f "$PROJECT_DIR/.scribe/preferences.md" "$PROJECT_DIR/.scribe/overview.md"
  rm -rf "$PROJECT_DIR/.scribe/weekly"
  echo "kept" > "$PROJECT_DIR/.scribe/lessons.md"
  start_hook >/dev/null
  [ -f "$PROJECT_DIR/.scribe/preferences.md" ]
  [ -f "$PROJECT_DIR/.scribe/overview.md" ]
  [ -d "$PROJECT_DIR/.scribe/weekly" ]
  grep -qx kept "$PROJECT_DIR/.scribe/lessons.md"
}
