#!/usr/bin/env bats

# Session start: the size limit, the home folder list, kit journals and the
# smaller fixes.

load helpers

setup() {
  setup_isolated_env
  P="$HOME/projects"
}
teardown() { teardown_isolated_env; }

start_in() {
  printf '{"cwd":"%s","session_id":"%s","source":"startup"}' "$1" "${2:-s1}" | "$VELLUM_BIN" hook session-start
}

# A journal a few weeks old: 15 decisions, 25 logbook days, 8 preference
# topics, 18 lessons and a long overview.
big_journal() {
  local j="$1/.vellum" i d
  {
    printf -- '---\nid: overview\n---\n# Overview\n\n## What this is\n\nA garden planner for raised beds.\n\n## Recent sessions\n\n'
    echo "- 2026-10-16: Moved the bed layout to a twelve-column grid."
    for i in $(seq 1 60); do echo "- Point $i about where things stand, with enough words to take up a full line of text."; done
    printf '\n## Next steps\n\n- Confirm bed size and number.\n'
  } >"$j/overview.md"
  for i in $(seq -w 1 15); do
    printf -- '---\nid: d%s\ntype: decision\ndate: 2026-10-01\nsummary: Decision number %s chose one approach over two others because it was simpler to explain to the person.\nstatus: accepted\n---\n# Decision %s\n' "$i" "$i" "$i" >"$j/decisions/0$i-decision-$i.md"
  done
  for i in $(seq -w 1 25); do
    printf -- '---\nid: l%s\ntype: logbook\ndate: 2026-09-%s\nsummary: A day of work on the garden planner, covering layout, copy and the watering schedule in some detail.\n---\n# 2026-09-%s\n\nWork.\n' "$i" "$i" "$i" >"$j/logbook/2026-09-$i.md"
  done
  for i in $(seq 1 8); do
    printf '\n## Topic %s\n\n- Likes one column, top to bottom (2026-10-03: "too busy"). Rejected split screens twice and asked for calmer colours.\n- Wants plain English everywhere, short sentences, and no jargon at all in the interface text.\n' "$i" >>"$j/preferences.md"
  done
  for i in $(seq 1 18); do
    printf '\n## Area %s\n\n### Lesson: lesson number %s says something true beyond this project and explains why\n\nBody.\n' "$i" "$i" >>"$j/lessons.md"
  done
}

@test "budget: a big journal stays under Claude Code's 10,000 character limit" {
  "$VELLUM_BIN" new garden >/dev/null
  big_journal "$P/garden"
  mkdir -p "$HOME/.vellum/notices"
  echo "Journal updated after your last session: garden, 1 decision." > "$HOME/.vellum/notices/$("$VELLUM_BIN" __sanitize "$P/garden")"
  out="$(start_in "$P/garden")"
  [ "$(printf '%s' "$out" | wc -c)" -lt 10000 ]
  # It is valid JSON, and holds the recap, the instructions and the commands.
  printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["systemMessage"].startswith("Last time, 16 Oct:")'
  [[ "$out" == *"Last time, 16 Oct: Moved the bed layout"* ]] || false
  [[ "$out" == *"note things while the detail is fresh"* ]] || false
  [[ "$out" == *"Vellum runs this person"* ]] || false
  [[ "$out" == *"Read $P/garden/.vellum/INDEX.md for everything in it"* ]] || false
}

@test "budget: without a message the plain text also stays under the limit" {
  "$VELLUM_BIN" new garden >/dev/null
  big_journal "$P/garden"
  out="$(printf '{"cwd":"%s","session_id":"s1","source":"clear"}' "$P/garden" | "$VELLUM_BIN" hook session-start)"
  [ "$(printf '%s' "$out" | python3 -c 'import json,sys; print(len(json.dumps(sys.stdin.read())))')" -lt 10000 ]
  [[ "$out" == *"note things while the detail is fresh"* ]] || false
}

@test "budget: the project comes before the general commands" {
  "$VELLUM_BIN" new garden >/dev/null
  out="$(start_in "$P/garden")"
  before="${out%%Vellum runs this person*}"
  [[ "$before" == *"Journal for garden"* ]] || false
}

@test "budget: a small journal is shown whole, with no pointer" {
  "$VELLUM_BIN" new garden >/dev/null
  out="$(start_in "$P/garden")"
  [[ "$out" != *"parts of it were shortened"* ]] || false
}

@test "home: lists at most 40 projects, and never writes the project list" {
  mkdir -p "$HOME/.vellum"
  for i in $(seq 1 60); do
    mkdir -p "$P/p$i/.vellum/logbook"
    printf 'p%s\t%s\t%s\tactive\t2026-10-01\t\n' "$i" "$P/p$i" "$((3000 + i))" >>"$HOME/.vellum/projects.tsv"
  done
  touch "$P/p7/.vellum/logbook/2026-10-18.md"
  before="$(cksum < "$HOME/.vellum/projects.tsv")"
  out="$(start_in "$HOME")"
  [ "$(cksum < "$HOME/.vellum/projects.tsv")" = "$before" ]
  [[ "$out" == *"20 more active projects are not shown"* ]] || false
  # The most recent work comes first.
  list="${out#*most recent first}"
  [ "$(printf '%s\n' "$list" | grep -m1 'port ')" = "p7  (port 3007, last worked on 2026-10-18)" ]
}

@test "kit: session start writes nothing into a committed design-journal" {
  mkdir -p "$P/kitproj/design-journal/logbook"
  printf '# 2026-10-01\n\nKit work.\n' > "$P/kitproj/design-journal/logbook/2026-10-01.md"
  git -C "$P/kitproj" init -q
  git -C "$P/kitproj" add -A
  git -C "$P/kitproj" -c user.email=t@t -c user.name=t commit -qm init
  out="$(start_in "$P/kitproj")"
  [[ "$out" == *"Kit work."* ]] || false
  [[ "$out" == *'`logbook/2026-10-01.md`'* ]] || false
  [ -z "$(git -C "$P/kitproj" status --porcelain)" ]
}

@test "kit: one kit project waiting is called one project" {
  mkdir -p "$P/allotment"
  echo '{"projects": {"allotment": 3019}}' > "$P/.ports.json"
  out="$(start_in "$HOME")"
  [[ "$out" == *"has 1 project in $P that is not on the project list yet"* ]] || false
}

@test "kit: no import offer for the kit project this session is adding" {
  mkdir -p "$P/allotment/design-journal"
  echo '{"projects": {"allotment": 3019}}' > "$P/.ports.json"
  out="$(start_in "$P/allotment")"
  [[ "$out" != *"not on the project list yet"* ]] || false
  grep -q "^allotment	$P/allotment	3019" "$HOME/.vellum/projects.tsv"
}

@test "paused: Claude still gets a short recap and may read the journal" {
  "$VELLUM_BIN" new garden >/dev/null
  printf -- '---\nid: overview\n---\n# Overview\n\n## Recent sessions\n\n- 2026-10-16: Chose raised beds.\n' > "$P/garden/.vellum/overview.md"
  cd "$P/garden" && "$VELLUM_BIN" pause >/dev/null
  out="$(start_in "$P/garden")"
  [[ "$out" == *"Vellum is paused for this project"* ]] || false
  [[ "$out" == *"Last time, 16 Oct: Chose raised beds."* ]] || false
  [[ "$out" != *"note things while the detail is fresh"* ]] || false
}

@test "print_project_context: prints the session start block for a project" {
  "$VELLUM_BIN" new garden >/dev/null
  run bash -c "set -u; VELLUM_BIN_PATH='$VELLUM_BIN'; PLUGIN_ROOT='$VELLUM_REPO'; TEMPLATES='$VELLUM_REPO/templates'
    VELLUM_HOME='$HOME/.vellum'; LIBRARY=\"\$VELLUM_HOME/library\"; CONFIG=\"\$VELLUM_HOME/config\"; DECLINED=\"\$VELLUM_HOME/declined\"
    GLOBAL_LOG=\"\$VELLUM_HOME/vellum.log\"; REGISTRY=\"\$VELLUM_HOME/projects.tsv\"; SESSIONS=\"\$VELLUM_HOME/sessions\"; HOME_P='$HOME'
    OLD_HOME='$HOME/.scribe'; JOURNAL_NAME=.vellum; LESSONS=lessons.md
    for f in common journal projects recall hooks theme; do . '$VELLUM_REPO/lib/'\$f.sh; done
    print_project_context '$P/garden'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"note things while the detail is fresh"* ]] || false
  [[ "$output" == *"Journal for garden"* ]] || false
}

@test "recap: drops a dash after the date and checklist markers" {
  "$VELLUM_BIN" new garden >/dev/null
  printf -- '---\nid: overview\n---\n# Overview\n\n## Recent sessions\n\n- [x] 2026-10-16 — Moved the beds.\n\n## Next steps\n\n- [ ] Order soil.\n' > "$P/garden/.vellum/overview.md"
  out="$(start_in "$P/garden")"
  [[ "$out" == *'"systemMessage":"Last time, 16 Oct: Moved the beds. Next: Order soil."'* ]] || false
}

@test "instructions: with the curator off, Claude is not told one will run" {
  "$VELLUM_BIN" new garden >/dev/null
  "$VELLUM_BIN" config background off >/dev/null
  out="$(start_in "$P/garden")"
  [[ "$out" != *"A curator organises everything"* ]] || false
  [[ "$out" == *"curator is switched off"* ]] || false
  "$VELLUM_BIN" config background on >/dev/null
  out="$(start_in "$P/garden")"
  [[ "$out" == *"A curator organises everything"* ]] || false
}

@test "session id: without one, nothing is recorded against a made-up session" {
  "$VELLUM_BIN" new garden >/dev/null
  out="$(printf '{"cwd":"%s"}' "$P/garden" | "$VELLUM_BIN" hook session-start)"
  [ ! -e "$HOME/.vellum/sessions/unknown" ]
  [[ "$out" != *"--session"* ]] || false
  [[ "$out" != *"{{"* ]] || false
}

@test "worktree: a git worktree is offered a journal" {
  make_git_repo
  git -C "$PROJECT_DIR" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$PROJECT_DIR" worktree add -q "$TEST_HOME/wt" 2>/dev/null
  out="$(start_in "$TEST_HOME/wt")"
  [[ "$out" == *"not one of their projects yet"* ]] || false
}
