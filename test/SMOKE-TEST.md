# Manual test

The automated tests use a fake `claude`. This checklist tests the plugin with real Claude Code. Run it on a Mac before each release.

## Before you start

- Claude Code 2.1.292 or later.
- No other copy of Vellum installed. If an old curl install is present, step 2 covers it.
- A throwaway home folder for the installer steps, so your own settings, fonts and Terminal profiles are not changed. For example, a second macOS user account.
- A throwaway project: `mkdir -p /tmp/vellum-smoke && cd /tmp/vellum-smoke && git init`.

## Steps

1. **Install.** Run `claude plugin install vellum --marketplace jasontheodorou/vellum`. For an unreleased copy, start Claude with `claude --plugin-dir /path/to/vellum` instead.
2. **Old install.** On a machine with the old curl version, Claude should mention it in its first reply. Say yes. Check that `~/.claude/settings.json` no longer mentions `.scribe/hooks/` and `~/.vellum/library/` is still there.
3. **Asked once.** In `/tmp/vellum-smoke`, start Claude. Its first reply asks whether to keep a journal.
4. **Yes.** Answer yes. Check that `.vellum/` exists, `git status` is clean, and there is no `CLAUDE.md` or `.gitignore`.
5. **Writing as you go.** Discuss a small decision. Check `.vellum/logbook/<today>.md`, and `.vellum/decisions/001-*.md` if a decision was made.
6. **Curator.** Quit Claude. Within three minutes `.vellum/.state/helper.log` ends with one line saying what changed. Check that the logbook covers the whole session, `overview.md` is filled in, any decision has Options considered, `preferences.md` quotes you, and `INDEX.md` lists every entry.
7. **Coming back.** Start Claude again. Ask "where did we get to?". It answers from the journal without opening files you name.
8. **Pause.** Say "pause journaling". Check `.vellum/.paused` exists. Work a little and quit. Nothing new is written, and the curator does not run.
9. **Resume.** Say "resume journaling". Check `.vellum/.paused` is gone.
10. **Slash commands.** Run `/vellum:status`. It reports the state in plain English.
11. **Curator off.** Say "stop the background curator". Quit. The curator does not run. Turn it back on.
12. **Archive.** Say "archive this project". `vellum-smoke_archive.md` appears on the desktop with a real summary, and a copy is in `~/.vellum/library/`.
13. **Past projects.** In a second throwaway project, turn journaling on and ask "have we made decisions about X before?", where X is in the first project. Claude finds it.
14. **Link.** Say "bring in what we learned on vellum-smoke". Start a new session and check that its summary and lessons are in context.
15. **No.** In a third project, answer no. Check `~/.vellum/declined` lists it. Start Claude again: it does not ask.
16. **Not now.** In a fourth project, answer "not now". Start Claude again: it asks again.
17. **Old journal.** Make a project with a `journal/` folder and a `CLAUDE.md` containing `<!-- scribe-block-begin -->` and `<!-- scribe-block-end -->`. Claude offers to migrate. Say yes and check the result.
18. **Turn off.** Say "turn off journaling here". Claude asks you to confirm. Confirm, and check `.vellum/` is gone.
19. **Start a project.** In your home folder, start Claude and say "start a new project called smoke test for trying things out". Check `~/projects/smoke-test` has git, a README and `.vellum/`, and that it is on the list.
20. **List and open.** Say "what projects do I have?", then "open smoke test". Claude answers from the journal.
21. **Search.** Say "have I dealt with X in any other project?", where X is in another project's journal. Claude finds and explains it.
22. **Rename and close.** Say "rename smoke test to smoke trial", then "we're done with smoke trial". Claude asks before closing, saves a write-up to the desktop, and the project disappears from the list but not from disk.
23. **Kit projects.** On a machine with the project kit, say "import my projects", then open one. Claude offers to switch it over. Say yes and check `.claude/settings.json` and `~/Library/LaunchAgents`.
24. **Before pushing.** In a project with commits, say "is it safe to push?".
25. **Several windows.** Open three Claude Code windows in different projects at once, start a project in one, and quit them all within a few seconds. Check `~/.vellum/projects.tsv` still lists every project once, and each project's curator ran.
26. **Pause stops recall.** In a paused project, have a short conversation and quit. Check no new copy of it appears in `~/.vellum/recall/` (a file with `# skip: yes` is fine).
27. **Long journal.** In a project whose journal has many lessons and a long index, start Claude and ask "what do you know about this project?". Claude answers from the overview, so the session-start context arrived.
28. **Scribe to Vellum.** In a throwaway home folder with `~/.scribe/` and a project with a `.scribe/` journal, start Claude with Vellum installed. Check `~/.scribe` has moved to `~/.vellum`, and that opening the project moves `.scribe/` to `.vellum/`.
29. **Installer, fresh.** In a throwaway home folder with a `~/.claude/settings.json` that sets `"theme": "dark"`, run the install command from the README. Check that the welcome screen appears in a new yellow Vellum window, Terminal's default profile is Vellum, Paper Mono is in `~/Library/Fonts`, `settings.json` has `"theme": "custom:vellum"` and a `statusLine`, `~/.claude/themes/vellum.json` exists, the lines above and below the input are faint blue, and `settings.json.before-vellum` has `"theme": "dark"` and no `enabledPlugins`.
30. **Installer, again.** Run the install command a second time. It succeeds and shows the welcome screen again. `settings.json.before-vellum` still has `"theme": "dark"`.
31. **Theme.** Run `~/.vellum/bin/vellum theme undo`. New Terminal windows open in the old default profile, and `settings.json` has `"theme": "dark"` again. Run `~/.vellum/bin/vellum theme` to put Vellum back.
32. **Uninstall.** Run `/plugin uninstall vellum`. New sessions say nothing about Vellum. Journals and the library are untouched.

## Results

| Date | Version | System | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-10-19 | 0.10.0 beta | macOS 26, Claude Code 2.1.303 | Pass after fixes | Installed from GitHub with the one-line installer into a fresh throwaway home folder. The plugin, helper, fonts, Terminal profile, Claude theme, status line and welcome screen were all set up, and a real session loaded the plugin. A review then found problems, including the installer replacing its own backup, recall copying paused projects and session start exceeding Claude Code's size limit. These were fixed. |
| 2026-10-16 | Pre-0.9 run | macOS 26, Claude Code 2.1.301 | Partial pass | Steps 2 (detection only), 3, 4, 6 and 12 run with `--plugin-dir` in headless mode. The helper could not write outside `.vellum/`, change README.md or run commands. |
| 2026-10-17 | 0.9.0 beta | macOS 26, Claude Code 2.1.301 | Pass after fixes | 15 live sessions in a sandbox: start, rename, pause, list, close (asked first, archived), list all, reopen and resume; import kit copies and switch one over; recall from real history; Haiku curator then undo in a new session; pre-push check caught a planted key; "put this on GitHub" asked first and made no calls; install from the marketplace into a throwaway config. Fixed: names with spaces, false success after an unknown project, the curator redoing an undone update, unclear import and weekly-job messages. |
| 2026-10-17 | Pre-0.9 run | macOS 26, Claude Code 2.1.301 | Pass | A four-turn conversation in one session (stream-json input, so turns arrived together): started a project, created files, changed the plan, asked what was decided. The curator recorded the decision and two preferences in your words in 30 seconds. A new session opened with the "last time" line and the curator's note, and Claude recalled and followed both preferences. |
| 2026-10-16 | Pre-0.9 run | macOS 26, Claude Code 2.1.301 | Pass | Steps 19 to 21 in headless mode with a throwaway project list. "Start a new project called garden planner" created the project, wrote a file and recorded a decision; the curator then rewrote the overview in 33 seconds. "Have I dealt with drainage in any other project?" found and explained a decision in another project. |
| 2026-10-16 | Pre-0.9 run | macOS 26, Claude Code 2.1.301 | Pass | Step 6 with the curator, on a copy of a real project journal and a real 20 MB session (condensed to 41 KB). Took 141 seconds. It wrote the logbook, 2 decisions, 2 experiments, 6 lessons, preferences and 3 terms, marked 6 decisions as replaced and rewrote the overview. |
