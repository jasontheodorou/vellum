#!/usr/bin/env bats

load helpers

setup() {
  setup_isolated_env
  mkdir -p "$HOME/.claude/commands" "$HOME/.scribe/bin" "$HOME/.scribe/hooks" "$HOME/.scribe/templates" "$HOME/.scribe/library"
  cat > "$HOME/.claude/settings.json" <<JSON
{
  "model": "opus",
  "hooks": {
    "SessionStart": [
      {"scribe": true, "hooks": [{"type": "command", "command": "$HOME/.scribe/hooks/session-start.sh"}]},
      {"hooks": [{"type": "command", "command": "/other/hook.sh"}]}
    ],
    "Stop": [
      {"scribe": true, "hooks": [{"type": "command", "command": "$HOME/.scribe/hooks/stop.sh"}]}
    ]
  }
}
JSON
  echo "Run scribe pause" > "$HOME/.claude/commands/journal-pause.md"
  echo "my own command" > "$HOME/.claude/commands/journal-status.md"
  printf 'export FOO=1\n\n# scribe\nexport PATH="$HOME/.scribe/bin:$PATH"\n' > "$HOME/.zshrc"
  echo "keep me" > "$HOME/.scribe/library/old_archive.md"
}
teardown() { teardown_isolated_env; }

@test "remove-old-install removes only the old Scribe hooks" {
  run "$VELLUM_BIN" remove-old-install
  [ "$status" -eq 0 ]
  refute grep -q ".scribe/hooks" "$HOME/.claude/settings.json"
  grep -q "/other/hook.sh" "$HOME/.claude/settings.json"
  grep -q '"model": "opus"' "$HOME/.claude/settings.json"
  refute grep -q '"Stop"' "$HOME/.claude/settings.json"
  [ -f "$HOME/.claude/settings.json.vellum-backup" ]
}

@test "remove-old-install works with python3 when jq is missing" {
  mkdir -p "$TEST_HOME/nojq"
  for t in bash sh grep sed awk cat cp mv rm mkdir mktemp head tail tr dirname basename python3; do
    p=$(command -v $t) && ln -sf "$p" "$TEST_HOME/nojq/$t"
  done
  PATH="$TEST_HOME/nojq" run "$VELLUM_BIN" remove-old-install
  [ "$status" -eq 0 ]
  refute grep -q ".scribe/hooks" "$HOME/.claude/settings.json"
  grep -q "/other/hook.sh" "$HOME/.claude/settings.json"
}

@test "remove-old-install removes old commands but not the person's own" {
  "$VELLUM_BIN" remove-old-install
  [ ! -f "$HOME/.claude/commands/journal-pause.md" ]
  [ -f "$HOME/.claude/commands/journal-status.md" ]
}

@test "remove-old-install removes the PATH line and keeps the rest" {
  "$VELLUM_BIN" remove-old-install
  refute grep -q ".scribe/bin" "$HOME/.zshrc"
  refute grep -qx "# scribe" "$HOME/.zshrc"
  grep -q "export FOO=1" "$HOME/.zshrc"
}

@test "remove-old-install keeps the library" {
  "$VELLUM_BIN" remove-old-install
  [ ! -d "$HOME/.scribe/bin" ]
  [ ! -d "$HOME/.scribe/hooks" ]
  grep -q "keep me" "$HOME/.vellum/library/old_archive.md"
  [ ! -d "$HOME/.scribe" ]
}

@test "remove-old-install is safe to run twice" {
  "$VELLUM_BIN" remove-old-install
  run "$VELLUM_BIN" remove-old-install
  [ "$status" -eq 0 ]
}

@test "remove-old-install writes through a linked ~/.zshrc and keeps the link" {
  mkdir -p "$HOME/dotfiles"
  mv "$HOME/.zshrc" "$HOME/dotfiles/zshrc"
  ln -s "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
  run "$VELLUM_BIN" remove-old-install
  [ "$status" -eq 0 ]
  [ -L "$HOME/.zshrc" ]
  refute grep -q ".scribe/bin" "$HOME/dotfiles/zshrc"
  grep -q "export FOO=1" "$HOME/dotfiles/zshrc"
}

@test "remove-old-install empties a shell file that held only the old line" {
  printf 'export PATH="$HOME/.scribe/bin:$PATH"\n' > "$HOME/.bashrc"
  run "$VELLUM_BIN" remove-old-install
  [ "$status" -eq 0 ]
  [[ "$output" == *"Removed the old PATH line from $HOME/.bashrc"* ]] || false
  [ ! -s "$HOME/.bashrc" ]
  [ -z "$(ls "$HOME" | grep '\.tmp$')" ]
}

@test "remove-old-install says so when it cannot change a shell file" {
  chmod 444 "$HOME/.zshrc"
  run "$VELLUM_BIN" remove-old-install
  chmod 644 "$HOME/.zshrc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"could not remove the old PATH line"* ]] || false
  [[ "$output" != *"Removed the old PATH line from $HOME/.zshrc"* ]] || false
}

@test "remove-old-install uses CLAUDE_CONFIG_DIR" {
  mkdir -p "$TEST_HOME/cfg/commands"
  mv "$HOME/.claude/settings.json" "$TEST_HOME/cfg/settings.json"
  echo "Run scribe resume" > "$TEST_HOME/cfg/commands/journal-resume.md"
  CLAUDE_CONFIG_DIR="$TEST_HOME/cfg" run "$VELLUM_BIN" remove-old-install
  [ "$status" -eq 0 ]
  refute grep -q ".scribe/hooks" "$TEST_HOME/cfg/settings.json"
  [ ! -f "$TEST_HOME/cfg/commands/journal-resume.md" ]
}
