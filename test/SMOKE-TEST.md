# Manual test

The automated tests use a fake `claude`. This checklist tests the plugin with real Claude Code. Run it on a Mac before each release.

## Before you start

- Claude Code 2.1.292 or later.
- No other copy of Vellum installed.
- A throwaway home folder for the installer steps, so your own settings, fonts and Terminal profiles are not changed. For example, a second macOS user account.
- A throwaway project: `mkdir -p /tmp/vellum-smoke && cd /tmp/vellum-smoke && git init`.

## Steps

1. **Install.** Run `claude plugin install vellum --marketplace jasontheodorou/vellum`. For an unreleased copy, start Claude with `claude --plugin-dir /path/to/vellum` instead.
2. **Asked once.** In `/tmp/vellum-smoke`, start Claude. Its first reply asks whether to keep a journal.
3. **Yes.** Answer yes. Check that `.vellum/` exists, `git status` is clean, and there is no `CLAUDE.md` or `.gitignore`.
4. **Writing as you go.** Discuss a small decision. Check `.vellum/logbook/<today>.md`, and `.vellum/decisions/001-*.md` if a decision was made.
5. **Curator.** Quit Claude. Within three minutes `.vellum/.state/helper.log` ends with one line saying what changed. Check that the logbook covers the whole session, `overview.md` is filled in, any decision has Options considered, `preferences.md` quotes you, and `INDEX.md` lists every entry.
6. **Coming back.** Start Claude again. Ask "where did we get to?". It answers from the journal without opening files you name.
7. **Pause.** Say "pause journaling". Check `.vellum/.paused` exists. Work a little and quit. Nothing new is written, and the curator does not run.
8. **Resume.** Say "resume journaling". Check `.vellum/.paused` is gone.
9. **Slash commands.** Run `/vellum:status`. It reports the state in plain English.
10. **Curator off.** Say "stop the background curator". Quit. The curator does not run. Turn it back on.
11. **Archive.** Say "archive this project". `vellum-smoke_archive.md` appears on the desktop with a real summary, and a copy is in `~/.vellum/library/`.
12. **Past projects.** In a second throwaway project, turn journaling on and ask "have we made decisions about X before?", where X is in the first project. Claude finds it.
13. **Link.** Say "bring in what we learned on vellum-smoke". Start a new session and check that its summary and lessons are in context.
14. **No.** In a third project, answer no. Check `~/.vellum/declined` lists it. Start Claude again: it does not ask.
15. **Not now.** In a fourth project, answer "not now". Start Claude again: it asks again.
16. **Turn off.** Say "turn off journaling here". Claude asks you to confirm. Confirm, and check `.vellum/` is gone.
17. **Start a project.** In your home folder, start Claude and say "start a new project called smoke test for trying things out". Check `~/projects/smoke-test` has git, a README and `.vellum/`, and that it is on the list.
18. **List and open.** Say "what projects do I have?", then "open smoke test". Claude answers from the journal.
19. **Search.** Say "have I dealt with X in any other project?", where X is in another project's journal. Claude finds and explains it.
20. **Rename and close.** Say "rename smoke test to smoke trial", then "we're done with smoke trial". Claude asks before closing, saves a write-up to the desktop, and the project disappears from the list but not from disk.
21. **Before pushing.** In a project with commits, say "is it safe to push?".
22. **Several windows.** Open three Claude Code windows in different projects at once, start a project in one, and quit them all within a few seconds. Check `~/.vellum/projects.tsv` still lists every project once, and each project's curator ran.
23. **Pause stops recall.** In a paused project, have a short conversation and quit. Check no new copy of it appears in `~/.vellum/recall/` (a file with `# skip: yes` is fine).
24. **Long journal.** In a project whose journal has many lessons and a long index, start Claude and ask "what do you know about this project?". Claude answers from the overview, so the session-start context arrived.
25. **Installer, fresh.** In a throwaway home folder with a `~/.claude/settings.json` that sets `"theme": "dark"`, run the install command from the README. Check that the welcome screen appears in a new yellow Vellum window, Terminal's default profile is Vellum, Paper Mono is in `~/Library/Fonts`, `settings.json` has `"theme": "custom:vellum"` and a `statusLine`, `~/.claude/themes/vellum.json` exists, the lines above and below the input are faint blue, and `settings.json.before-vellum` has `"theme": "dark"` and no `enabledPlugins`.
26. **Installer, again.** Run the install command a second time. It succeeds and shows the welcome screen again. `settings.json.before-vellum` still has `"theme": "dark"`.
27. **Theme.** Run `~/.vellum/bin/vellum theme undo`. New Terminal windows open in the old default profile, and `settings.json` has `"theme": "dark"` again. Run `~/.vellum/bin/vellum theme` to put Vellum back.
28. **Uninstall.** Run `/plugin uninstall vellum`. New sessions say nothing about Vellum. Journals and the library are untouched.
