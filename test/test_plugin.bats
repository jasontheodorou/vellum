#!/usr/bin/env bats

load helpers

@test "plugin.json and marketplace.json name the same plugin" {
  a=$(sed -n 's/^  "name": *"\([^"]*\)".*/\1/p' "$VELLUM_REPO/.claude-plugin/plugin.json")
  grep -q "\"name\": \"$a\"" "$VELLUM_REPO/.claude-plugin/marketplace.json"
}

@test "every hook command points at a script that exists" {
  grep -o '/bin/vellum\\" hook [a-z-]*' "$VELLUM_REPO/hooks/hooks.json" | while read -r line; do
    sub=${line##* }
    cat "$VELLUM_REPO/bin/vellum" "$VELLUM_REPO"/lib/*.sh | grep -q "$sub)"
  done
  [ -x "$VELLUM_REPO/bin/vellum" ]
}

@test "every skill has a description" {
  for f in "$VELLUM_REPO"/skills/*/SKILL.md; do
    grep -q "^description: " "$f"
  done
}

@test "the instructions mention every command Claude may run" {
  for c in pause resume curate undo archive link "off --yes" new open list rename close reopen adopt import-kit running stop search recall digest preship publish config doctor; do
    cat "$VELLUM_REPO/templates/instructions.md" "$VELLUM_REPO/templates/projects.md" | grep -q "vellum $c"
  done
}

@test "no file in the plugin uses an em dash" {
  refute grep -rl $'\xe2\x80\x94' "$VELLUM_REPO/bin" "$VELLUM_REPO/templates" "$VELLUM_REPO/skills" "$VELLUM_REPO/hooks" "$VELLUM_REPO/.claude-plugin"
}

@test "the curator prompt has every placeholder filled in by the script" {
  for ph in $(grep -o '{{[A-Z_]*}}' "$VELLUM_REPO/templates/curator.md" | sort -u); do
    case "$ph" in "{{PROJECT}}"|"{{J}}"|"{{LESSONS}}"|"{{TODAY}}"|"{{SESSION_NOTE}}") ;; *) echo "unknown $ph"; return 1 ;; esac
  done
}
