#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "doctor: healthy when claude is present and there is no old install" {
  install_fake_claude
  run "$VELLUM_BIN" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Everything looks healthy"* ]] || false
}

@test "doctor: reports a missing claude" {
  run "$VELLUM_BIN" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"Claude Code is not on PATH"* ]] || false
}

@test "doctor: reports a leftover old install" {
  install_fake_claude
  mkdir -p "$HOME/.claude"
  echo '{"hooks":{"Stop":[{"scribe":true,"hooks":[{"type":"command","command":"/x/.scribe/hooks/stop.sh"}]}]}}' > "$HOME/.claude/settings.json"
  run "$VELLUM_BIN" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"remove-old-install"* ]] || false
}

@test "doctor: prints the plugin version" {
  install_fake_claude
  version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$VELLUM_REPO/.claude-plugin/plugin.json")
  run "$VELLUM_BIN" doctor
  [[ "${lines[0]}" == *"$version"* ]] || false
}

@test "doctor: finds the old install in a Claude folder set by CLAUDE_CONFIG_DIR" {
  install_fake_claude
  mkdir -p "$HOME/other-claude"
  echo '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"/x/.scribe/hooks/stop.sh"}]}]}}' > "$HOME/other-claude/settings.json"
  CLAUDE_CONFIG_DIR="$HOME/other-claude" run "$VELLUM_BIN" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"remove-old-install"* ]] || false
}
