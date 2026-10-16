#!/usr/bin/env bats

load helpers

@test "plugin.json and marketplace.json name the same plugin" {
  a=$(sed -n 's/^  "name": *"\([^"]*\)".*/\1/p' "$SCRIBE_REPO/.claude-plugin/plugin.json")
  grep -q "\"name\": \"$a\"" "$SCRIBE_REPO/.claude-plugin/marketplace.json"
}

@test "every hook command points at a script that exists" {
  grep -o '/bin/scribe\\" hook [a-z-]*' "$SCRIBE_REPO/hooks/hooks.json" | while read -r line; do
    sub=${line##* }
    grep -q "$sub)" "$SCRIBE_REPO/bin/scribe"
  done
  [ -x "$SCRIBE_REPO/bin/scribe" ]
}

@test "every skill has a description" {
  for f in "$SCRIBE_REPO"/skills/*/SKILL.md; do
    grep -q "^description: " "$f"
  done
}

@test "the instructions mention every command Claude may run" {
  for c in pause resume status archive link "config background off" "off --yes"; do
    grep -q "scribe $c" "$SCRIBE_REPO/templates/instructions.md"
  done
}

@test "no file in the plugin uses an em dash" {
  refute grep -rl $'\xe2\x80\x94' "$SCRIBE_REPO/bin" "$SCRIBE_REPO/templates" "$SCRIBE_REPO/skills" "$SCRIBE_REPO/hooks" "$SCRIBE_REPO/.claude-plugin"
}
