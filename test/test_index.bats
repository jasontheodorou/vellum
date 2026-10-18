#!/usr/bin/env bats

load helpers

setup() { setup_isolated_env; "$VELLUM_BIN" init >/dev/null; J="$PROJECT_DIR/.vellum"; }
teardown() { teardown_isolated_env; }

@test "init builds an index" {
  [ -f "$J/INDEX.md" ]
  grep -q '`overview.md`: Where the project stands today' "$J/INDEX.md"
}

@test "index uses the summary, with date and status" {
  printf -- '---\nid: d1\ndate: 2026-10-01\nstatus: accepted\nsummary: "Sign-in uses magic links."\n---\n# 001 Magic links\n' > "$J/decisions/001-magic-links.md"
  "$VELLUM_BIN" index
  grep -qxF -- '- `decisions/001-magic-links.md` (2026-10-01, accepted): Sign-in uses magic links.' "$J/INDEX.md"
}

@test "index falls back to the title when there is no summary" {
  printf -- '---\nid: d2\ntopic: hosting\n---\n# 002 Host on Vercel\n' > "$J/decisions/002-host.md"
  "$VELLUM_BIN" index
  grep -qF -- '- `decisions/002-host.md`: 002 Host on Vercel' "$J/INDEX.md"
}

@test "index copes with an entry with no frontmatter" {
  echo "# Just a heading" > "$J/experiments/2026-10-01-x.md"
  "$VELLUM_BIN" index
  grep -qF -- '- `experiments/2026-10-01-x.md`: Just a heading' "$J/INDEX.md"
}

@test "index lists the logbook newest first and stops at 30 days" {
  for d in $(seq -w 1 31); do echo "# 2026-08-$d" > "$J/logbook/2026-08-$d.md"; done
  "$VELLUM_BIN" index
  first=$(grep -m1 'logbook/2026-08' "$J/INDEX.md")
  [[ "$first" == *"2026-08-31"* ]] || false
  grep -q '\.\.\.and 1 older days' "$J/INDEX.md"
  refute grep -q 'logbook/2026-08-01.md' "$J/INDEX.md"
}

@test "index lists themed files and artefacts" {
  echo "# Bugs" > "$J/bugs.md"
  echo "old" > "$J/artefacts/2026-10-01-old-home.css"
  "$VELLUM_BIN" index
  grep -qF '`bugs.md`: Bugs' "$J/INDEX.md"
  grep -qF '`artefacts/2026-10-01-old-home.css`' "$J/INDEX.md"
  refute grep -q '\.keep' "$J/INDEX.md"
}

@test "index does not list itself or the readme" {
  "$VELLUM_BIN" index
  refute grep -q '`INDEX.md`' "$J/INDEX.md"
  refute grep -q '`README.md`' "$J/INDEX.md"
}
