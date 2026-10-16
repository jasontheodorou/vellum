#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; }
teardown() { teardown_isolated_env; }

@test "doctor: healthy when claude is present and there is no old install" {
  install_fake_claude
  run "$SCRIBE_BIN" doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"Everything looks healthy"* ]]
}

@test "doctor: reports a missing claude" {
  run "$SCRIBE_BIN" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"Claude Code is not on PATH"* ]]
}

@test "doctor: reports a leftover old install" {
  install_fake_claude
  mkdir -p "$HOME/.claude"
  echo '{"hooks":{"Stop":[{"scribe":true,"hooks":[{"type":"command","command":"/x/.scribe/hooks/stop.sh"}]}]}}' > "$HOME/.claude/settings.json"
  run "$SCRIBE_BIN" doctor
  [ "$status" -ne 0 ]
  [[ "$output" == *"remove-old-install"* ]]
}

@test "doctor: prints the plugin version" {
  install_fake_claude
  version=$(sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' "$SCRIBE_REPO/.claude-plugin/plugin.json")
  run "$SCRIBE_BIN" doctor
  [[ "${lines[0]}" == *"$version"* ]]
}
