#!/usr/bin/env bats
# Fixes from the end-to-end test of 19 October 2026: the project list under
# load, publishing, project folders, names and the smaller project commands.

load helpers

setup() {
  setup_isolated_env
  P="$HOME/projects"
  REG="$HOME/.vellum/projects.tsv"
}
teardown() {
  [ -n "${LISTENER:-}" ] && kill "$LISTENER" 2>/dev/null
  teardown_isolated_env
}

line_for() {
  printf '{"cwd":"%s","session_id":"%s"}' "$1" "${2:-}" | "$VELLUM_BIN" statusline | sed 's/\x1b\[[0-9;]*m//g'
}

# A program listening on a port, started from a given folder.
listen() {
  (cd "$2" && exec perl -MIO::Socket::INET -e '
    my $s = IO::Socket::INET->new(LocalAddr => "127.0.0.1", LocalPort => $ARGV[0], Listen => 1, ReuseAddr => 1) or die;
    sleep 60' "$1") &
  LISTENER=$!
  for _ in $(seq 1 50); do
    lsof -nP -iTCP:"$1" -sTCP:LISTEN -t >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

free_port() {
  local port=$((40000 + RANDOM % 20000))
  while lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1; do port=$((port + 1)); done
  echo "$port"
}

fake_gh() {
  cat >"$FAKEBIN/gh" <<FAKE
#!/bin/bash
echo "\$@" >> "\$TEST_HOME/gh.calls"
case "\$1 \$2" in
  "repo create") exit ${1:-0} ;;
  "repo view") exit 1 ;;
esac
exit 0
FAKE
  chmod +x "$FAKEBIN/gh"
}

commit_all() {
  git add -A && git -c user.email=t@t -c user.name=t commit -qm init
}

# --- B3: the project list under load ----------------------------------------

@test "list: 30 status lines at once lose no projects and write nothing" {
  mkdir -p "$P/a" "$P/b" "$P/c" "$HOME/.vellum"
  printf 'a\t%s\t3001\tactive\t2026-01-01\t\n' "$P/a" >"$REG.new"
  printf 'b\t%s\t3002\tactive\t2026-01-01\t\n' "$P/b" >>"$REG.new"
  printf 'c\t%s\t3003\tactive\t2026-01-01\t\t◆\n' "$P/c" >>"$REG.new"
  mv "$REG.new" "$REG"
  before="$(cksum <"$REG")"
  for i in $(seq 1 30); do
    d=a; [ $((i % 3)) -eq 1 ] && d=b; [ $((i % 3)) -eq 2 ] && d=c
    printf '{"cwd":"%s"}' "$P/$d" | "$VELLUM_BIN" statusline >/dev/null &
  done
  wait
  [ "$(grep -c . "$REG")" -eq 3 ]
  [ "$(cksum <"$REG")" = "$before" ]
}

@test "list: many projects added at once are all kept" {
  for i in $(seq 1 20); do mkdir -p "$P/p$i"; done
  for i in $(seq 1 20); do "$VELLUM_BIN" adopt "$P/p$i" >/dev/null 2>&1 & done
  wait
  [ "$(grep -c . "$REG")" -eq 20 ]
  [ ! -d "$REG.lock" ]
  [ -z "$(ls "$HOME/.vellum" | grep 'projects.tsv\.')" ]
}

@test "list: a project gets its shape when it is added" {
  "$VELLUM_BIN" new garden >/dev/null
  [ "$(cut -f7 "$REG")" = "●" ]
}

@test "list: an older list gets shapes from the next command, and the status line shows them without writing" {
  mkdir -p "$P/a" "$P/b" "$HOME/.vellum"
  printf 'a\t%s\t3001\tactive\t2026-01-01\t\nb\t%s\t3002\tactive\t2026-01-01\t\n' "$P/a" "$P/b" >"$REG"
  [ "$(line_for "$P/b")" = "◆ b" ]
  [ -z "$(cut -f7 "$REG" | tr -d '\n')" ]
  run "$VELLUM_BIN" list
  [[ "$output" == *"● a"* && "$output" == *"◆ b"* ]] || false
  [ -z "$(cut -f7 "$REG" | tr -d '\n')" ]
  "$VELLUM_BIN" digest >/dev/null
  [ "$(cut -f7 "$REG" | tr '\n' ' ')" = "● ◆ " ]
}

@test "list: a lock left behind by a stopped process is cleared" {
  mkdir -p "$HOME/.vellum/projects.tsv.lock"
  touch -t 202001010000 "$HOME/.vellum/projects.tsv.lock"
  run "$VELLUM_BIN" new garden
  [ "$status" -eq 0 ]
  grep -q "^garden	" "$REG"
}

@test "list: blank lines and Windows line endings are skipped" {
  "$VELLUM_BIN" new garden >/dev/null
  printf '\n\r\n' >>"$REG"
  run "$VELLUM_BIN" list
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == "● garden  (port 3001, no sessions yet)" ]] || false
}

@test "list: marks a project whose folder is missing" {
  "$VELLUM_BIN" new garden >/dev/null
  rm -rf "$P/garden"
  run "$VELLUM_BIN" list
  [[ "$output" == *"folder missing"* ]] || false
}

# --- B6 and S20: publishing ------------------------------------------------

@test "publish: a refusal from GitHub is not reported as published" {
  "$VELLUM_BIN" new shop >/dev/null
  cd "$P/shop" && commit_all
  fake_gh 1
  run "$VELLUM_BIN" publish
  [ "$status" -ne 0 ]
  [[ "$output" != *"Published"* ]] || false
  [[ "$output" == *"did not create the repository shop"* ]] || false
}

@test "publish: names the repository after the project, not the raw folder" {
  mkdir -p "$P/My Shop" && cd "$P/My Shop" && git init -q
  "$VELLUM_BIN" adopt >/dev/null
  echo "# My Shop" >README.md
  commit_all
  fake_gh 0
  run "$VELLUM_BIN" publish
  [ "$status" -eq 0 ]
  grep -q "repo create my-shop --private" "$TEST_HOME/gh.calls"
}

@test "publish: rejects an unknown option" {
  "$VELLUM_BIN" new shop >/dev/null
  cd "$P/shop" && commit_all
  fake_gh 0
  run "$VELLUM_BIN" publish --pubic
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown option '--pubic'"* ]] || false
  [ ! -f "$TEST_HOME/gh.calls" ] || refute grep -q "repo create" "$TEST_HOME/gh.calls"
}

@test "publish: a private repository needs no licence; a public one does" {
  "$VELLUM_BIN" new shop >/dev/null
  cd "$P/shop" && commit_all
  fake_gh 0
  run "$VELLUM_BIN" preship
  [ "$status" -eq 0 ]
  [[ "$output" == *"note   there is no LICENSE file"* ]] || false
  run "$VELLUM_BIN" publish --public
  [ "$status" -ne 0 ]
  [[ "$output" == *"check  there is no LICENSE file"* ]] || false
  run "$VELLUM_BIN" publish
  [ "$status" -eq 0 ]
  [[ "$output" == *"Published shop to GitHub (private)."* ]] || false
}

# --- S9 and S10: which folder is the project --------------------------------

@test "folders: a git repository in the home folder does not swallow folders below it" {
  git -C "$HOME" init -q
  mkdir -p "$HOME/stuff/deep" "$P/garden/src"
  cd "$HOME/stuff/deep"
  run "$VELLUM_BIN" adopt
  [ "$status" -eq 0 ]
  grep -q "	$HOME/stuff/deep	" "$REG"
  cd "$P/garden/src"
  run "$VELLUM_BIN" adopt
  [ "$status" -eq 0 ]
  grep -q "^garden	$P/garden	" "$REG"
}

@test "folders: a git repository in the projects folder does not swallow its projects" {
  mkdir -p "$P/garden/src"
  git -C "$P" init -q
  cd "$P/garden/src"
  run "$VELLUM_BIN" adopt
  [ "$status" -eq 0 ]
  grep -q "^garden	$P/garden	" "$REG"
}

@test "folders: a git worktree belongs to its main copy" {
  mkdir -p "$P/garden" && cd "$P/garden" && git init -q && commit_all 2>/dev/null ||
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  "$VELLUM_BIN" adopt >/dev/null
  git worktree add -q "$HOME/garden-wt" 2>/dev/null
  mkdir -p "$HOME/garden-wt/src"
  cd "$HOME/garden-wt/src"
  run "$VELLUM_BIN" adopt
  [[ "$output" == *"garden is already on the project list"* ]] || false
  [ "$(line_for "$HOME/garden-wt/src")" = "● garden" ]
}

# --- S15: stop ----------------------------------------------------------------

@test "stop: leaves alone a program from elsewhere that holds the port" {
  "$VELLUM_BIN" new garden >/dev/null
  port="$(free_port)"
  awk -F'\t' -v OFS='\t' -v p="$port" '{$3 = p} {print}' "$REG" >"$REG.x" && mv "$REG.x" "$REG"
  mkdir -p "$HOME/elsewhere"
  listen "$port" "$HOME/elsewhere"
  run "$VELLUM_BIN" stop garden
  [ "$status" -ne 0 ]
  [[ "$output" == *"not by garden"* ]] || false
  [[ "$output" != *"Stopped"* ]] || false
  kill -0 "$LISTENER"
}

@test "stop and running: stop the project's own server, with tidy process ids" {
  "$VELLUM_BIN" new garden >/dev/null
  port="$(free_port)"
  awk -F'\t' -v OFS='\t' -v p="$port" '{$3 = p} {print}' "$REG" >"$REG.x" && mv "$REG.x" "$REG"
  listen "$port" "$P/garden"
  run "$VELLUM_BIN" running
  [[ "$output" == "garden is running at http://localhost:$port (process $LISTENER)" ]] || false
  run "$VELLUM_BIN" stop garden
  [ "$status" -eq 0 ]
  [[ "$output" == *"Stopped garden (port $port)."* ]] || false
}

# --- S16 and S17: new and rename -------------------------------------------

@test "new: stops if the folder cannot be made, and records nothing" {
  mkdir -p "$P" && chmod 555 "$P"
  run "$VELLUM_BIN" new garden
  chmod 755 "$P"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not create"* ]] || false
  [ ! -s "$REG" ]
}

@test "new: caps a long name at 80 characters" {
  run "$VELLUM_BIN" new "$(printf 'a%.0s' $(seq 1 120))"
  [ "$status" -eq 0 ]
  [ "$(cut -f1 "$REG" | tr -d '\n' | wc -c | tr -d ' ')" -eq 80 ]
}

@test "new: uses every word of an unquoted name" {
  run "$VELLUM_BIN" new Patio Planner --about "Plans a patio."
  [ "$status" -eq 0 ]
  [ -d "$P/patio-planner" ]
  grep -q "Plans a patio." "$P/patio-planner/README.md"
}

@test "new: an option in place of the name is refused" {
  run "$VELLUM_BIN" new --about x
  [ "$status" -ne 0 ]
  run "$VELLUM_BIN" new --help
  [ "$status" -ne 0 ]
  [ ! -d "$P/about" ] && [ ! -d "$P/help" ] && [ ! -s "$REG" ]
}

@test "new: keeps backslashes in the description" {
  "$VELLUM_BIN" new garden --about 'Paths like C:\new\tasks stay.' >/dev/null
  grep -qF 'Paths like C:\new\tasks stay.' "$P/garden/.vellum/overview.md"
}

@test "new: says when git could not be set up" {
  cat >"$FAKEBIN/git" <<'FAKE'
#!/bin/bash
[ "$1" = "init" ] && exit 1
exec /usr/bin/git "$@"
FAKE
  chmod +x "$FAKEBIN/git"
  run "$VELLUM_BIN" new garden
  [ "$status" -eq 0 ]
  [[ "$output" != *"It has git"* ]] || false
  [[ "$output" == *"git could not be set up"* ]] || false
}

@test "new: a kit project already on the list is offered to open" {
  mkdir -p "$P/Portfolio"
  echo '{"projects": {"Portfolio": 3024}}' >"$P/.ports.json"
  "$VELLUM_BIN" import-kit >/dev/null
  run "$VELLUM_BIN" new Portfolio
  [ "$status" -ne 0 ]
  [[ "$output" == *"open portfolio"* ]] || false
  [[ "$output" != *"Say 'add"* ]] || false
}

@test "rename: refuses more than two names, and changes nothing" {
  "$VELLUM_BIN" new "garden planner" >/dev/null
  "$VELLUM_BIN" new veg >/dev/null
  run "$VELLUM_BIN" rename Garden Planner Veg Plot
  [ "$status" -ne 0 ]
  [[ "$output" == *"quotes"* ]] || false
  [ -d "$P/garden-planner" ] && [ -d "$P/veg" ]
}

@test "rename: a missing folder stops it, and the list is unchanged" {
  "$VELLUM_BIN" new garden >/dev/null
  rm -rf "$P/garden"
  before="$(cat "$REG")"
  run "$VELLUM_BIN" rename garden allotment
  [ "$status" -ne 0 ]
  [[ "$output" == *"missing"* ]] || false
  [ "$(cat "$REG")" = "$before" ]
}

@test "close, reopen and stop: take unquoted names of several words" {
  "$VELLUM_BIN" new "garden planner" >/dev/null
  "$VELLUM_BIN" new garden >/dev/null
  run "$VELLUM_BIN" close garden planner --no-archive
  [ "$status" -eq 0 ]
  grep -q "^garden-planner	.*	closed	" "$REG"
  grep -q "^garden	.*	active	" "$REG"
  run "$VELLUM_BIN" reopen garden planner
  [ "$status" -eq 0 ]
  grep -q "^garden-planner	.*	active	" "$REG"
  run "$VELLUM_BIN" stop garden planner
  [ "$status" -eq 0 ]
  [[ "$output" == "garden-planner is not running." ]] || false
}

# --- S18 and S19: adopt and import-kit ---------------------------------------

@test "adopt: folders with the same name get different names" {
  mkdir -p "$HOME/a/site" "$HOME/b/site" "$HOME/c/site"
  "$VELLUM_BIN" adopt "$HOME/a/site" >/dev/null
  "$VELLUM_BIN" adopt "$HOME/b/site" >/dev/null
  "$VELLUM_BIN" adopt "$HOME/c/site" >/dev/null
  [ "$(cut -f1 "$REG" | tr '\n' ' ')" = "site site-2 site-3 " ]
}

@test "adopt: a folder name with no plain letters becomes project" {
  mkdir -p "$HOME/日本"
  run "$VELLUM_BIN" adopt "$HOME/日本"
  [ "$status" -eq 0 ]
  grep -q "^project	" "$REG"
}

@test "adopt: refuses the top of the disk and folders that cannot be written to" {
  run "$VELLUM_BIN" adopt /
  [ "$status" -ne 0 ]
  mkdir -p "$HOME/locked" && chmod 555 "$HOME/locked"
  run "$VELLUM_BIN" adopt "$HOME/locked"
  chmod 755 "$HOME/locked"
  [ "$status" -ne 0 ]
  [[ "$output" == *"cannot be written to"* ]] || false
  [ ! -s "$REG" ]
}

@test "import-kit: makes names folder-safe, gives a port where the kit had none" {
  mkdir -p "$P/My Site" "$P/blank"
  echo '{"projects": {"My Site": 3020, "blank": null, "gone": 3021}}' >"$P/.ports.json"
  run "$VELLUM_BIN" list
  [[ "$output" == *"Your project kit has 2 project(s)"* ]] || false
  run "$VELLUM_BIN" import-kit
  [ "$status" -eq 0 ]
  grep -q "^my-site	$P/My Site	3020	" "$REG"
  grep -qE "^blank	$P/blank	[0-9]+	" "$REG"
  run "$VELLUM_BIN" open "My Site"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Project: my-site"* ]] || false
}

@test "import-kit: says when there is no kit" {
  run "$VELLUM_BIN" import-kit
  [[ "$output" == "No project kit was found in $P." ]] || false
}

# --- S21 and S22: settings and names ----------------------------------------

@test "config: a quoted ~ in projects-dir means the home folder" {
  run "$VELLUM_BIN" config projects-dir "~/code"
  [ "$status" -eq 0 ]
  [ -d "$HOME/code" ]
  [ ! -e "$PROJECT_DIR/~" ]
  grep -qx "projects-dir=$HOME/code" "$HOME/.vellum/config"
}

@test "names: accents are dropped, not turned into gaps" {
  "$VELLUM_BIN" new "Café Menu" >/dev/null
  [ -d "$P/cafe-menu" ]
  run "$VELLUM_BIN" open "café menu"
  [ "$status" -eq 0 ]
}

@test "names: a name with nothing usable says what to use" {
  run "$VELLUM_BIN" new "..."
  [ "$status" -ne 0 ]
  [[ "$output" == *"a–z, 0–9"* ]] || false
  run "$VELLUM_BIN" new "日本"
  [ "$status" -ne 0 ]
  [[ "$output" == *"a–z, 0–9"* ]] || false
}

@test "names: line breaks, leading dots and bad bytes are handled" {
  run "$VELLUM_BIN" new $'two\nlines'
  [ "$status" -eq 0 ]
  [ -d "$P/two-lines" ]
  run "$VELLUM_BIN" new ".hidden"
  [ -d "$P/hidden" ]
  run "$VELLUM_BIN" new $'bad\xffbyte'
  [ "$status" -eq 0 ]
  [[ "$output" != *"Illegal byte sequence"* ]] || false
  [ -d "$P/bad-byte" ]
}

# --- S23: the status line after switching projects --------------------------

@test "statusline: follows the project worked on most recently" {
  "$VELLUM_BIN" new garden >/dev/null
  "$VELLUM_BIN" new patio >/dev/null
  mkdir -p "$HOME/elsewhere"
  line_for "$P/garden" s1 >/dev/null
  line_for "$P/patio" s1 >/dev/null
  line_for "$P/garden" s1 >/dev/null
  [ "$(line_for "$HOME/elsewhere" s1)" = "● garden" ]
  [ "$(grep -c . "$HOME/.vellum/sessions/s1")" -eq 2 ]
}

@test "statusline: the projects folder itself is not a project" {
  "$VELLUM_BIN" new garden >/dev/null
  [ -z "$(line_for "$P" s2)" ]
  [ ! -f "$HOME/.vellum/sessions/s2" ] || refute grep -qx "$P" "$HOME/.vellum/sessions/s2"
}

# --- Smaller fixes -----------------------------------------------------------

@test "search: journal paths with | and other symbols" {
  mkdir -p "$HOME/odd|dir [x]"
  cd "$HOME/odd|dir [x]" && "$VELLUM_BIN" adopt >/dev/null
  echo "We picked tulips." >"$HOME/odd|dir [x]/.vellum/logbook/2026-01-01.md"
  run "$VELLUM_BIN" search tulips
  [ "$status" -eq 0 ]
  [[ "$output" == *".vellum/logbook/2026-01-01.md:1:We picked tulips."* ]] || false
  [[ "$output" != *"$HOME"* ]] || false
}

@test "digest: a number of days that is not a number is refused" {
  "$VELLUM_BIN" new garden >/dev/null
  run "$VELLUM_BIN" digest week
  [ "$status" -ne 0 ]
  [[ "$output" == *"as a number"* ]] || false
}

@test "preship: big files with spaces in their names, unknown visibility, and more keys" {
  "$VELLUM_BIN" new shop >/dev/null
  cd "$P/shop"
  dd if=/dev/zero of="big file.bin" bs=1024 count=6000 2>/dev/null
  echo 'API_KEY = "abcdefghijklmnopqrstu"' >a.js
  echo 'stripe = "sk_live_abcdefghijklmnop1234"' >b.js
  commit_all
  git remote add origin https://example.com/x.git
  fake_gh 0
  run "$VELLUM_BIN" preship
  [ "$status" -ne 0 ]
  [[ "$output" == *"           big file.bin"* ]] || false
  [[ "$output" == *"           a.js"* ]] || false
  [[ "$output" == *"           b.js"* ]] || false
  [[ "$output" == *"(visibility unknown)"* ]] || false
}

@test "close: an empty journal gives one clear line" {
  "$VELLUM_BIN" new garden >/dev/null
  run "$VELLUM_BIN" close garden
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "The journal is empty, so there was nothing to archive." ]
  [[ "${lines[1]}" == "Closed garden."* ]] || false
  [ "${#lines[@]}" -eq 2 ]
}

@test "close: says when the folder is missing; reopen says when already open" {
  "$VELLUM_BIN" new garden >/dev/null
  run "$VELLUM_BIN" reopen garden
  [ "$output" = "garden is already open." ]
  rm -rf "$P/garden"
  run "$VELLUM_BIN" close garden
  [ "$status" -eq 0 ]
  [[ "$output" == *"folder, $P/garden, is missing"* ]] || false
}

@test "vellum: runs through a symbolic link" {
  mkdir -p "$HOME/bin"
  ln -s "$VELLUM_BIN" "$HOME/bin/vellum"
  run "$HOME/bin/vellum" version
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  ln -s vellum "$HOME/bin/second-link"
  run "$HOME/bin/second-link" help
  [ "$status" -eq 0 ]
}

@test "kit: finds the weekly job whatever its prefix" {
  mkdir -p "$P/kitproj/design-journal" "$HOME/Library/LaunchAgents"
  touch "$HOME/Library/LaunchAgents/org.someone.design-journal-weekly-kitproj.plist"
  run "$VELLUM_BIN" adopt "$P/kitproj"
  [ "$status" -eq 0 ]
  [ -f "$HOME/.vellum/retired/org.someone.design-journal-weekly-kitproj.plist" ]
}

@test "help: lists projects-dir, theme skip, recall --show and close --no-archive" {
  run "$VELLUM_BIN" help
  [[ "$output" == *"projects-dir"* ]] || false
  [[ "$output" == *"theme skip"* ]] || false
  [[ "$output" == *"recall --show ID"* ]] || false
  [[ "$output" == *"--no-archive"* ]] || false
  [[ "$output" != *"reorganise"* ]] || false
}

@test "help: lists undo --earlier and off --delete-tracked" {
  run "$VELLUM_BIN" help
  [[ "$output" == *"undo --earlier"* ]] || false
  [[ "$output" == *"off --yes --delete-tracked"* ]] || false
}
