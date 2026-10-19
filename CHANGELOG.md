# Changelog

This project uses [semantic versioning](https://semver.org). The version lives in `.claude-plugin/plugin.json`.

## 0.10.0 beta (unreleased)

Scribe is now called Vellum, and sets up Apple's Terminal as well as Claude Code.

### Added

- `install.sh`: one Terminal command installs the Terminal theme, the plugin and the status line, sets Claude Code to "Light mode (ANSI colours only)" so it draws with Vellum's colours, removes Scribe (the plugin and the old curl install), and ends with a welcome screen. It backs up settings.json and is safe to run again.
- `vellum theme`: installs the Paper Mono font and the Vellum Terminal profile (Man Page brightened: sunny yellow, charcoal ink, Paper Mono 18 point, all 16 colours readable), and makes it the default for new and startup windows. `vellum theme undo` goes back to the previous profile.
- Return recap: after an hour or more away, your next prompt shows the one-line "Last time… Next…" recap, once. `vellum config recap-after MINUTES|off` changes or stops it. The installer turns off Claude Code's own recap, which appears after every five minutes away, and `vellum theme undo` turns it back on.
- Vellum's Claude Code theme: "Light mode (ANSI colours only)" with faint blue `#A9C2EC` lines above and below the input. `vellum theme` copies it to `~/.claude/themes/vellum.json`, and moves Claude Code onto it from plain "Light mode (ANSI colours only)". Those lines share Terminal's white with the message backgrounds, so the Terminal profile alone could not colour just them.
- Theme updates: when a new Vellum profile ships, the next session offers to apply it. `vellum theme` replaces the old profile, keeps it the default and refreshes windows already using it; `vellum theme skip` says no to that update.

### Changed

- Terminal's white, behind your messages in Claude Code, is now mint `#C6EDE3` in place of cream `#FFFADB`.
- Renamed from Scribe to Vellum: the plugin, the `vellum` command and the `/vellum:` slash commands.
- Data moves from `~/.scribe` to `~/.vellum` the first time Vellum runs, and each project's `.scribe/` journal moves to `.vellum/` when the project is next used. A "no" given to Scribe is still respected.
- The license in `plugin.json` is now "MIT AND OFL-1.1", because the Paper Mono font is under the SIL Open Font License. `LICENSE` and the README say so.
- `PRIVACY.md` now says what goes to Anthropic, every file Vellum keeps, everything the installer changes, and that condensed sessions keep up to 200 characters of each command Claude ran.

### Fixed

- The installer keeps the first backup of Claude Code's settings. Running it again used to replace the backup with Vellum's own settings. The backup is now taken before the plugin is installed, so it really is how the settings were before.
- The installer cannot be cut short when it is piped from `curl` into bash. It used to stop part way and still report success if a command it ran read the rest of the script.
- On a Mac without Apple's Command Line Tools, the installer now asks you to run `xcode-select --install`. It used to say the settings file was not valid JSON.
- The installer checks that Claude Code is 2.1.292 or later, and no longer reports success when it could not update the settings file.
- `vellum theme undo` also puts back Claude Code's theme, and says how to remove the status line.
- Session start always fits within Claude Code's 10,000 character limit, so a long journal no longer stops Claude getting its context.
- Session end hands all the work to a curator that runs on its own after Claude Code closes. Sessions that end together wait in a queue, so none is lost.
- Several windows open at once can no longer damage the project list.
- Publishing to GitHub now fails clearly when something goes wrong, in place of claiming success.
- "Stop X" stops only the project's own server, not another program using the same port.
- Pausing a project also stops its conversations being copied for recall, both at session end and when you search. Projects where you said no to a journal are skipped too.
- `vellum undo` puts back only the files the curator changed, and refuses if they were edited since, so notes written after the curator's run are kept. `vellum undo --earlier` goes back one more run.
- `vellum off --yes` refuses to delete a journal that is tracked by git. `--delete-tracked` deletes it anyway.
- The first recall search stops after 60 seconds and carries on next time, in place of making you wait for your whole history.
- A home folder that is itself a git repository (such as a dotfiles repository), and git worktrees, are handled properly.
- Project and folder names with accented letters work.
- Removing the old Scribe keeps a `~/.zshrc` that is a link to another file as a link.

## 0.9.0 beta (not released separately)

Scribe (formerly Terminal Scribe) is now a Claude Code plugin.

### Added

- `scribe undo` restores the journal to how it was before the curator's last run; the curator skips the session in which you undo.
- Recall: search every past Claude Code conversation on the computer ("why did we drop the Priorities page?"), with the date, project and the person's words. Conversations are condensed once into `~/.scribe/recall/` and refreshed as they change; background helper runs are skipped.
- A quiet status line: the project's name in its own colour and its own shape (● ◆ ▲ ■ …), so windows are easy to tell apart, plus the server, branch, unpushed commits or a paused journal only when they need attention.
- At the start of a session in a project, one line says what happened last time and what is next.
- One line at the start of the next session says what the curator changed.
- Each project's port is given to Claude and set as `PORT` for its commands, so servers start on the right port.
- Projects in plain English: start, open, list, rename, close, reopen and add projects. Each gets a folder in `~/projects`, git, a README, a journal and a port.
- Search every project's journal ("have I dealt with drainage before?"), and a digest of the week across projects.
- Checks before pushing code (passwords, keys, `.env` files, large files, a tracked journal), and publishing to GitHub.
- "What's running?" and "stop X" for projects with a local web server.
- Link a live project, not only an archived one, so its overview and lessons load in another project.
- Works with projects from the earlier project kit: `import-kit` brings them in with their ports, their `design-journal/` and training manual are used as they are, and adopting one retires the kit's own hooks and weekly job.
- Claude gets the project instructions in every session, wherever it starts, and the project list when it starts in the home folder.
- The curator organises every project a session worked on, not only the folder it started in.
- A curator runs when each session ends. It records the session, pulls out decisions, experiments, lessons, preferences and terms, marks replaced decisions, rewrites the overview and writes a weekly round-up.
- The curator reads a condensed copy of the session, about a hundredth of the size of the full record.
- New journal files: `overview.md`, `preferences.md`, `INDEX.md` (rebuilt automatically from each entry's summary), `weekly/` and `artefacts/`.
- `scribe curate` runs the curator straight away ("tidy the journal").
- Claude now starts each session with the overview, your preferences, the titles of every lesson and the index, in place of the whole of the latest logbook.
- Install with `/plugin install scribe --marketplace jasontheodorou/terminal-scribe`.
- Slash commands: `/scribe:status`, `pause`, `resume`, `archive`, `enable` and `off`.
- `scribe config` turns the background helper on or off, and sets the model it uses.
- `scribe migrate` moves a project from the old `journal/` folder to `.scribe/`.
- `scribe remove-old-install` removes the version installed by the curl script, and keeps the library.
- `PRIVACY.md`, `CONTRIBUTING.md` and `SECURITY.md`.
- Tests run on macOS for every change. Scribe is for macOS only.

### Changed

- The journal moved from `journal/` to `.scribe/`, so it no longer clashes with projects that have their own journal folder.
- The journal is kept out of git with `.git/info/exclude`. Scribe no longer edits `.gitignore` or `CLAUDE.md`, which teams usually share.
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
