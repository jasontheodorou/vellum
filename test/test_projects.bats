#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  P="$HOME/projects"
}
teardown() { teardown_isolated_env; }

reg() { cat "$HOME/.scribe/projects.tsv"; }

@test "new: creates the folder, git, readme, journal and registers it" {
  run "$SCRIBE_BIN" new "Garden Planner" --about "Plans a vegetable garden." --session s1
  [ "$status" -eq 0 ]
  [ -d "$P/garden-planner/.git" ]
  grep -qx "# garden-planner" "$P/garden-planner/README.md"
  grep -q "Plans a vegetable garden." "$P/garden-planner/README.md"
  [ -f "$P/garden-planner/.scribe/overview.md" ]
  grep -q "Plans a vegetable garden." "$P/garden-planner/.scribe/overview.md"
  grep -qx "/.scribe/" "$P/garden-planner/.git/info/exclude"
  reg | grep -q "^garden-planner	$P/garden-planner	3001	active	"
  grep -qx "$P/garden-planner" "$HOME/.scribe/sessions/s1"
  [[ "$output" == *"Journal for garden-planner"* ]]
}

@test "new: gives each project the next port" {
  "$SCRIBE_BIN" new one >/dev/null
  "$SCRIBE_BIN" new two >/dev/null
  reg | grep -q "^two	.*	3002	"
}

@test "new: continues after the project kit's ports" {
  mkdir -p "$P"
  echo '{"next": 3025, "projects": {"katsura": 3019, "portfolio": 3024}}' > "$P/.ports.json"
  "$SCRIBE_BIN" new fresh >/dev/null
  reg | grep -q "^fresh	.*	3025	"
}

@test "new: refuses a name that is taken" {
  "$SCRIBE_BIN" new garden >/dev/null
  run "$SCRIBE_BIN" new Garden
  [ "$status" -ne 0 ]
  [[ "$output" == *"already a project called garden"* ]]
}

@test "new: refuses an existing folder" {
  mkdir -p "$P/garden"
  run "$SCRIBE_BIN" new garden
  [ "$status" -ne 0 ]
  [[ "$output" == *"add garden to my projects"* ]]
}

@test "open: finds a project by part of its name and prints its journal" {
  "$SCRIBE_BIN" new garden-planner >/dev/null
  run "$SCRIBE_BIN" open Garden --session s2
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project: garden-planner"* ]]
  [[ "$output" == *"folder: $P/garden-planner"* ]]
  [[ "$output" == *"Journal for garden-planner"* ]]
  grep -qx "$P/garden-planner" "$HOME/.scribe/sessions/s2"
}

@test "open: an ambiguous name lists the choices" {
  "$SCRIBE_BIN" new garden-one >/dev/null
  "$SCRIBE_BIN" new garden-two >/dev/null
  run "$SCRIBE_BIN" open garden
  [ "$status" -ne 0 ]
  [[ "$output" == *"garden-one"* ]]
  [[ "$output" == *"garden-two"* ]]
}

@test "open: an unknown name says how to see the list" {
  "$SCRIBE_BIN" new garden >/dev/null
  run "$SCRIBE_BIN" open kitchen
  [ "$status" -ne 0 ]
  [[ "$output" == *"list my projects"* ]]
}

@test "list: newest work first, with summaries, and hides closed projects" {
  "$SCRIBE_BIN" new older --about "The older one." >/dev/null
  "$SCRIBE_BIN" new newer --about "The newer one." >/dev/null
  "$SCRIBE_BIN" new gone >/dev/null
  echo "# x" > "$P/older/.scribe/logbook/2026-01-01.md"
  echo "# x" > "$P/newer/.scribe/logbook/2026-02-01.md"
  "$SCRIBE_BIN" close gone --no-archive >/dev/null
  run "$SCRIBE_BIN" list
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "newer  (port 3002, last worked on 2026-02-01)" ]]
  [[ "${lines[1]}" == *"The newer one."* ]]
  [[ "$output" != *"gone  ("* ]]
  [[ "$output" == *"1 closed project"* ]]
  run "$SCRIBE_BIN" list --all
  [[ "$output" == *"gone  (port 3003, no sessions yet, closed "* ]]
}

@test "list: reads the project kit's one-sentence description" {
  mkdir -p "$P/kitproj/design-journal"
  printf '# kitproj\n\n**One-sentence description:** A calm life dashboard.\n' > "$P/kitproj/design-journal/overview.md"
  "$SCRIBE_BIN" adopt "$P/kitproj" >/dev/null
  run "$SCRIBE_BIN" list
  [[ "$output" == *"A calm life dashboard."* ]]
}

@test "rename: moves the folder, updates the list and notes it in the logbook" {
  "$SCRIBE_BIN" new garden >/dev/null
  run "$SCRIBE_BIN" rename garden allotment
  [ "$status" -eq 0 ]
  [ ! -d "$P/garden" ]
  [ -d "$P/allotment/.scribe" ]
  reg | grep -q "^allotment	$P/allotment	"
  refute grep -q "^garden	" "$HOME/.scribe/projects.tsv"
  grep -q "Renamed from garden to allotment" "$P/allotment/.scribe/logbook/$(date '+%Y-%m-%d').md"
}

@test "rename: refuses a name that is taken" {
  "$SCRIBE_BIN" new a >/dev/null
  "$SCRIBE_BIN" new b >/dev/null
  run "$SCRIBE_BIN" rename a b
  [ "$status" -ne 0 ]
  [ -d "$P/a" ]
}

@test "close: archives, marks closed and keeps the folder" {
  install_fake_claude
  mkdir -p "$HOME/Desktop"
  "$SCRIBE_BIN" new garden >/dev/null
  echo "# 2026-03-01" > "$P/garden/.scribe/logbook/2026-03-01.md"
  run "$SCRIBE_BIN" close garden
  [ "$status" -eq 0 ]
  [ -f "$HOME/Desktop/garden_archive.md" ]
  [ -d "$P/garden" ]
  reg | grep -q "^garden	.*	closed	.*	$(date '+%Y-%m-%d')$"
  run "$SCRIBE_BIN" reopen garden
  reg | grep -q "^garden	.*	active	"
}

@test "close: still closes a project with an empty journal" {
  "$SCRIBE_BIN" new garden >/dev/null
  run "$SCRIBE_BIN" close garden
  [ "$status" -eq 0 ]
  reg | grep -q "^garden	.*	closed	"
}

@test "adopt: adds the current folder and starts a journal" {
  mkdir -p "$P/existing" && cd "$P/existing" && git init -q
  run "$SCRIBE_BIN" adopt --session s3
  [ "$status" -eq 0 ]
  [ -d "$P/existing/.scribe" ]
  reg | grep -q "^existing	$P/existing	"
  grep -qx "$P/existing" "$HOME/.scribe/sessions/s3"
}

@test "adopt: a second time says it is already listed" {
  mkdir -p "$P/existing"
  "$SCRIBE_BIN" adopt "$P/existing" >/dev/null
  run "$SCRIBE_BIN" adopt "$P/existing"
  [[ "$output" == *"already on the project list"* ]]
  [ "$(grep -c '^existing' "$HOME/.scribe/projects.tsv")" -eq 1 ]
}

@test "adopt: keeps a kit project's design-journal and training manual" {
  mkdir -p "$P/kitproj/design-journal/logbook"
  echo "# Training manual" > "$P/kitproj/design-journal/training-manual.md"
  (cd "$P/kitproj" && git init -q)
  "$SCRIBE_BIN" adopt "$P/kitproj" >/dev/null
  [ ! -d "$P/kitproj/.scribe" ]
  [ -f "$P/kitproj/design-journal/overview.md" ]
  [ -f "$P/kitproj/design-journal/preferences.md" ]
  [ ! -f "$P/kitproj/design-journal/lessons.md" ]
  refute grep -q "design-journal" "$P/kitproj/.git/info/exclude"
}

@test "adopt: retires the kit's hooks and weekly job, keeping backups" {
  mkdir -p "$P/kitproj/design-journal" "$P/kitproj/.claude" "$HOME/Library/LaunchAgents"
  cat > "$P/kitproj/.claude/settings.json" <<JSON
{"permissions": {"allow": ["Bash(npm *)"]},
 "hooks": {"SessionStart": [{"hooks": [{"type": "command", "command": "$P/kitproj/.claude/hooks/session-start.sh"}]}],
           "Stop": [{"hooks": [{"type": "command", "command": "$P/kitproj/design-journal/.journal-hook.sh"}]}]}}
JSON
  touch "$HOME/Library/LaunchAgents/com.jasont.design-journal-weekly-kitproj.plist"
  run "$SCRIBE_BIN" adopt "$P/kitproj"
  [ "$status" -eq 0 ]
  refute grep -q "journal-hook" "$P/kitproj/.claude/settings.json"
  refute grep -q "session-start.sh" "$P/kitproj/.claude/settings.json"
  grep -q "Bash(npm \*)" "$P/kitproj/.claude/settings.json"
  [ -f "$P/kitproj/.claude/settings.json.kit-backup" ]
  [ ! -f "$HOME/Library/LaunchAgents/com.jasont.design-journal-weekly-kitproj.plist" ]
  [ -f "$HOME/.scribe/retired/com.jasont.design-journal-weekly-kitproj.plist" ]
}

@test "adopt: takes the port the kit gave the project" {
  mkdir -p "$P/katsura"
  echo '{"next": 3025, "projects": {"katsura": 3019}}' > "$P/.ports.json"
  "$SCRIBE_BIN" adopt "$P/katsura" >/dev/null
  reg | grep -q "^katsura	.*	3019	"
}

@test "import-kit: adds every kit project that still exists" {
  mkdir -p "$P/katsura" "$P/sanctum"
  echo '{"next": 3025, "projects": {"katsura": 3019, "sanctum": 3022, "deleted": 3001}}' > "$P/.ports.json"
  run "$SCRIBE_BIN" import-kit
  [ "$status" -eq 0 ]
  [[ "$output" == *"Added 2 project(s)"* ]]
  reg | grep -q "^katsura	$P/katsura	3019	active"
  reg | grep -q "^sanctum	$P/sanctum	3022	active"
  refute grep -q "^deleted" "$HOME/.scribe/projects.tsv"
  run "$SCRIBE_BIN" import-kit
  [[ "$output" == *"Added 0 project(s)"* ]]
}

@test "search: finds words across projects and the library" {
  "$SCRIBE_BIN" new one >/dev/null
  "$SCRIBE_BIN" new two >/dev/null
  echo "We chose magic links for sign-in." > "$P/one/.scribe/decisions/001-auth.md"
  echo "Nothing relevant." > "$P/two/.scribe/logbook/2026-01-01.md"
  mkdir -p "$HOME/.scribe/library"
  echo "Old project also used Magic Links." > "$HOME/.scribe/library/old_archive.md"
  run "$SCRIBE_BIN" search "magic links"
  [ "$status" -eq 0 ]
  [[ "$output" == *"## one"* ]]
  [[ "$output" == *".scribe/decisions/001-auth.md:1:We chose magic links"* ]]
  [[ "$output" != *"## two"* ]]
  [[ "$output" == *"library/old_archive.md"* ]]
}

@test "search: says when nothing matches" {
  "$SCRIBE_BIN" new one >/dev/null
  run "$SCRIBE_BIN" search "zebra crossing"
  [[ "$output" == *"Nothing in any journal mentions"* ]]
}

@test "digest: shows recent logbook headings and decisions per project" {
  "$SCRIBE_BIN" new one >/dev/null
  today="$(date '+%Y-%m-%d')"
  printf '# %s\n\n## Moved sign-in to magic links\n' "$today" > "$P/one/.scribe/logbook/$today.md"
  echo "# Old" > "$P/one/.scribe/logbook/2000-01-01.md"
  printf -- '---\ndate: %s\nsummary: Use magic links.\n---\n' "$today" > "$P/one/.scribe/decisions/001-auth.md"
  run "$SCRIBE_BIN" digest 7
  [[ "$output" == *"## one"* ]]
  [[ "$output" == *"Moved sign-in to magic links"* ]]
  [[ "$output" == *"decision: Use magic links."* ]]
  [[ "$output" != *"2000-01-01"* ]]
}

@test "preship: passes a clean repository" {
  "$SCRIBE_BIN" new clean >/dev/null
  cd "$P/clean"
  echo "MIT" > LICENSE
  git add -A && git -c user.email=t@t -c user.name=t commit -qm init
  run "$SCRIBE_BIN" preship
  [ "$status" -eq 0 ]
  [[ "$output" == *"Nothing to fix."* ]]
}

@test "preship: catches keys, .env files and a tracked journal" {
  "$SCRIBE_BIN" new leaky >/dev/null
  cd "$P/leaky"
  echo 'token = "ghp_abcdefghijklmnopqrstuvwxyz0123456789"' > config.js
  echo "SECRET=1" > .env.local
  git add -A && git add -f .env.local .scribe/overview.md
  run "$SCRIBE_BIN" preship
  [ "$status" -ne 0 ]
  [[ "$output" == *"config.js"* ]]
  [[ "$output" == *".env.local"* ]]
  [[ "$output" == *"private journal in .scribe/ is tracked"* ]]
}

@test "publish: creates a private repository with gh" {
  "$SCRIBE_BIN" new pub >/dev/null
  cd "$P/pub"
  echo "MIT" > LICENSE
  git add -A && git -c user.email=t@t -c user.name=t commit -qm init
  cat > "$FAKEBIN/gh" <<'FAKE'
#!/bin/bash
echo "$@" >> "$TEST_HOME/gh.calls"
exit 0
FAKE
  chmod +x "$FAKEBIN/gh"
  run "$SCRIBE_BIN" publish
  [ "$status" -eq 0 ]
  grep -q "repo create pub --private --source=. --remote=origin --push" "$TEST_HOME/gh.calls"
}

@test "publish: refuses without commits" {
  "$SCRIBE_BIN" new empty >/dev/null
  cd "$P/empty"
  printf '#!/bin/bash\nexit 0\n' > "$FAKEBIN/gh" && chmod +x "$FAKEBIN/gh"
  run "$SCRIBE_BIN" publish
  [ "$status" -ne 0 ]
  [[ "$output" == *"no commits yet"* ]]
}

@test "link: a live project's overview loads at session start" {
  "$SCRIBE_BIN" new source --about "The source project." >/dev/null
  "$SCRIBE_BIN" new target >/dev/null
  cd "$P/target"
  run "$SCRIBE_BIN" link source
  [ "$status" -eq 0 ]
  grep -qx "project:source" "$P/target/.scribe/.imports"
  run bash -c "printf '{\"cwd\":\"%s\",\"session_id\":\"s\"}' '$P/target' | '$SCRIBE_BIN' hook session-start"
  [[ "$output" == *'Background from the linked project "source"'* ]]
  [[ "$output" == *"The source project."* ]]
}

@test "session-start: registers a journal folder that is not on the list" {
  mkdir -p "$PROJECT_DIR" && cd "$PROJECT_DIR"
  "$SCRIBE_BIN" init >/dev/null
  printf '{"cwd":"%s","session_id":"s9"}' "$PROJECT_DIR" | "$SCRIBE_BIN" hook session-start >/dev/null
  reg | grep -q "^test-project	$PROJECT_DIR	"
  grep -qx "$PROJECT_DIR" "$HOME/.scribe/sessions/s9"
}

@test "session-start: offers to switch a kit project over" {
  mkdir -p "$P/kitproj/design-journal" "$P/kitproj/.claude"
  echo '{"hooks":{"Stop":[{"hooks":[{"command":"x/design-journal/.journal-hook.sh"}]}]}}' > "$P/kitproj/.claude/settings.json"
  run bash -c "printf '{\"cwd\":\"%s\",\"session_id\":\"s\"}' '$P/kitproj' | '$SCRIBE_BIN' hook session-start"
  [[ "$output" == *"project kit's own hooks"* ]]
  [[ "$output" == *"Journal for kitproj"* ]]
  [[ "$output" == *"design-journal/logbook"* ]]
}

@test "session-start: offers to import the kit when the list is empty" {
  mkdir -p "$P"
  echo '{"projects": {"katsura": 3019}}' > "$P/.ports.json"
  run bash -c "printf '{\"cwd\":\"%s\",\"session_id\":\"s\"}' '$HOME' | '$SCRIBE_BIN' hook session-start"
  [[ "$output" == *"import-kit"* ]]
}

@test "session-end: curates every project the session opened" {
  install_fake_claude
  "$SCRIBE_BIN" new one --session multi >/dev/null
  "$SCRIBE_BIN" new two --session multi >/dev/null
  T="$SCRIBE_REPO/test/fixtures/session.jsonl"
  printf '{"cwd":"%s","session_id":"multi","transcript_path":"%s"}' "$HOME" "$T" | "$SCRIBE_BIN" hook session-end
  wait_for_file "$P/two/.scribe/.state/multi"
  [ -f "$P/one/.scribe/.state/multi" ]
  [ "$(grep -c '"one"' "$TEST_HOME/claude.stdin")" -ge 1 ]
  [ "$(grep -c '"two"' "$TEST_HOME/claude.stdin")" -ge 1 ]
  grep -q "Record only the work on" "$TEST_HOME/claude.stdin"
  [ ! -f "$HOME/.scribe/sessions/multi" ]
}

@test "config: projects-dir changes where new projects go" {
  "$SCRIBE_BIN" config projects-dir "$HOME/work" >/dev/null
  "$SCRIBE_BIN" new garden >/dev/null
  [ -d "$HOME/work/garden" ]
}

@test "paths: a projects folder reached through a shortcut is never listed twice" {
  mkdir -p "$HOME/real-projects"
  ln -s "$HOME/real-projects" "$HOME/link-projects"
  "$SCRIBE_BIN" config projects-dir "$HOME/link-projects" >/dev/null
  "$SCRIBE_BIN" new garden >/dev/null
  printf '{"cwd":"%s","session_id":"s"}' "$HOME/real-projects/garden" | "$SCRIBE_BIN" hook session-start >/dev/null
  printf '{"cwd":"%s","session_id":"s"}' "$HOME/link-projects/garden" | "$SCRIBE_BIN" hook session-start >/dev/null
  [ "$(grep -c . "$HOME/.scribe/projects.tsv")" -eq 1 ]
  out=$(printf '{"cwd":"%s"}' "$HOME/link-projects/garden" | "$SCRIBE_BIN" statusline | sed 's/\x1b\[[0-9;]*m//g')
  [[ "$out" == "● garden"* ]]
}
