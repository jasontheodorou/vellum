# Changelog

This project uses [semantic versioning](https://semver.org). The version lives in `.claude-plugin/plugin.json`.

## 1.0.0 (unreleased)

Terminal Scribe is now a Claude Code plugin.

### Added

- A curator runs when each session ends. It records the session, pulls out decisions, experiments, lessons, preferences and terms, marks replaced decisions, rewrites the overview and writes a weekly round-up.
- The curator reads a condensed copy of the session, about a hundredth of the size of the full record.
- New journal files: `overview.md`, `preferences.md`, `INDEX.md` (rebuilt automatically from each entry's summary), `weekly/` and `artefacts/`.
- `scribe curate` runs the curator straight away ("tidy the journal").
- Claude now starts each session with the overview, your preferences, the titles of every lesson and the index, in place of the whole of the latest logbook.
- Install with `/plugin install terminal-scribe --marketplace jasontheodorou/terminal-scribe`.
- Slash commands: `/terminal-scribe:status`, `pause`, `resume`, `archive`, `enable` and `off`.
- `scribe config` turns the background helper on or off, and sets the model it uses.
- `scribe migrate` moves a project from the old `journal/` folder to `.scribe/`.
- `scribe remove-old-install` removes the version installed by the curl script, and keeps the library.
- `PRIVACY.md`, `CONTRIBUTING.md` and `SECURITY.md`.
- Tests run on macOS and Linux for every change.

### Changed

- The journal moved from `journal/` to `.scribe/`, so it no longer clashes with projects that have their own journal folder.
- The journal is kept out of git with `.git/info/exclude`. Terminal Scribe no longer edits `.gitignore` or `CLAUDE.md`, which teams usually share.
- Claude gets its journal instructions when each session starts, so they no longer live in `CLAUDE.md`.
- The background helper runs once when a session ends. It used to run each time Claude replied, up to once every five minutes, and saved every run to your session history.
- The background helper can only write inside `.scribe/`, and it cannot run commands or use the web. It used to run with every permission check switched off.
- Archive summaries are written by a Claude run that can only read files.
- Saying no to journaling is remembered in `~/.scribe/declined`, so no marker file is left in the project.
- Lessons are grouped by topic and kind (lesson, insight, technique, pattern), in place of a list by date.

### Removed

- The curl installer, the bundled copies of `jq` and the changes to shell start-up files.

### Fixed

- On macOS, archives left every entry's heading at the top level.
- Archives broke on journal file names with spaces in them.

## 0.1.8 and earlier

Versions installed with the curl script. See the [releases page](https://github.com/jasontheodorou/terminal-scribe/releases).
