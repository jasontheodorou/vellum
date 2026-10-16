# Manual test

The automated tests use a fake `claude`. This checklist tests the plugin with real Claude Code. Run it on a Mac before each release, and on Linux when you can.

## Before you start

- Claude Code 2.1.275 or later.
- No other copy of Terminal Scribe installed. If an old curl install is present, step 2 covers it.
- A throwaway project: `mkdir -p /tmp/scribe-smoke && cd /tmp/scribe-smoke && git init`.

## Steps

1. **Install.** In Claude Code, run `/plugin install terminal-scribe --marketplace jasontheodorou/terminal-scribe`. For an unreleased copy, start Claude with `claude --plugin-dir /path/to/terminal-scribe` instead.
2. **Old install.** On a machine with the old curl version, Claude should mention it in its first reply. Say yes. Check that `~/.claude/settings.json` no longer mentions `.scribe/hooks/` and `~/.scribe/library/` is still there.
3. **Asked once.** In `/tmp/scribe-smoke`, start Claude. Its first reply asks whether to keep a journal.
4. **Yes.** Answer yes. Check that `.scribe/` exists, `git status` is clean, and there is no `CLAUDE.md` or `.gitignore`.
5. **Writing as you go.** Discuss a small decision. Check `.scribe/logbook/<today>.md`, and `.scribe/decisions/001-*.md` if a decision was made.
6. **Curator.** Quit Claude. Within three minutes `.scribe/.state/helper.log` ends with one line saying what changed. Check that the logbook covers the whole session, `overview.md` is filled in, any decision has Options considered, `preferences.md` quotes you, and `INDEX.md` lists every entry.
7. **Coming back.** Start Claude again. Ask "where did we get to?". It answers from the journal without opening files you name.
8. **Pause.** Say "pause journaling". Check `.scribe/.paused` exists. Work a little and quit. Nothing new is written, and the helper does not run.
9. **Resume.** Say "resume journaling". Check `.scribe/.paused` is gone.
10. **Slash commands.** Run `/terminal-scribe:status`. It reports the state in plain English.
11. **Helper off.** Say "stop the Terminal Scribe background helper". Quit. The helper does not run. Turn it back on.
12. **Archive.** Say "archive this project". `scribe-smoke_archive.md` appears on the desktop with a real summary, and a copy is in `~/.scribe/library/`.
13. **Past projects.** In a second throwaway project, turn journaling on and ask "have we made decisions about X before?", where X is in the first project. Claude finds it.
14. **Link.** Say "bring in what we learned on scribe-smoke". Start a new session and check that its summary and lessons are in context.
15. **No.** In a third project, answer no. Check `~/.scribe/declined` lists it. Start Claude again: it does not ask.
16. **Not now.** In a fourth project, answer "not now". Start Claude again: it asks again.
17. **Old journal.** Make a project with a `journal/` folder and a `CLAUDE.md` containing `<!-- scribe-block-begin -->` and `<!-- scribe-block-end -->`. Claude offers to migrate. Say yes and check the result.
18. **Turn off.** Say "turn off journaling here". Claude asks you to confirm. Confirm, and check `.scribe/` is gone.
19. **Start a project.** In your home folder, start Claude and say "start a new project called smoke test for trying things out". Check `~/projects/smoke-test` has git, a README and `.scribe/`, and that it is on the list.
20. **List and open.** Say "what projects do I have?", then "open smoke test". Claude answers from the journal.
21. **Search.** Say "have I dealt with X in any other project?", where X is in another project's journal. Claude finds and explains it.
22. **Rename and close.** Say "rename smoke test to smoke trial", then "we're done with smoke trial". Claude asks before closing, saves a write-up to the desktop, and the project disappears from the list but not from disk.
23. **Kit projects.** On a machine with the project kit, say "import my projects", then open one. Claude offers to switch it over. Say yes and check `.claude/settings.json` and `~/Library/LaunchAgents`.
24. **Before pushing.** In a project with commits, say "is it safe to push?".
25. **Uninstall.** Run `/plugin uninstall terminal-scribe`. New sessions say nothing about Terminal Scribe. Journals and the library are untouched.

## Results

| Date | Version | System | Result | Notes |
| --- | --- | --- | --- | --- |
| 2026-10-16 | 1.0.0 (unreleased) | macOS 26, Claude Code 2.1.301 | Partial pass | Steps 2 (detection only), 3, 4, 6 and 12 run with `--plugin-dir` in headless mode. The helper could not write outside `.scribe/`, change README.md or run commands. |
| 2026-10-17 | 1.0.0 (unreleased) | macOS 26, Claude Code 2.1.301 | Pass | A four-turn conversation in one session (stream-json input, so turns arrived together): started a project, created files, changed the plan, asked what was decided. The curator recorded the decision and two preferences in your words in 30 seconds. A new session opened with the "last time" line and the curator's note, and Claude recalled and followed both preferences. |
| 2026-10-16 | 1.0.0 (unreleased) | macOS 26, Claude Code 2.1.301 | Pass | Steps 19 to 21 in headless mode with a throwaway project list. "Start a new project called garden planner" created the project, wrote a file and recorded a decision; the curator then rewrote the overview in 33 seconds. "Have I dealt with drainage in any other project?" found and explained a decision in another project. |
| 2026-10-16 | 1.0.0 (unreleased) | macOS 26, Claude Code 2.1.301 | Pass | Step 6 with the curator, on a copy of a real project journal and a real 20 MB session (condensed to 41 KB). Took 141 seconds. It wrote the logbook, 2 decisions, 2 experiments, 6 lessons, preferences and 3 terms, marked 6 decisions as replaced and rewrote the overview. |
