# Privacy and data

Terminal Scribe has no server of its own and sends nothing anywhere itself. Everything it writes stays on your computer.

## What is recorded

When journaling is on for a project, Claude writes notes about your sessions into `.scribe/` in that project:

- a logbook of what happened each day
- decisions and the reasons for them
- experiments and their results
- lessons and project vocabulary

Claude is told never to copy passwords, API keys, tokens or personal data into the journal, and to describe them instead. That is an instruction to Claude, not a guarantee, so look through a journal before you share it.

## Who can see it

- **Git.** The journal is listed in `.git/info/exclude`, which only exists on your computer. It is never committed, and your team's `.gitignore` is not changed.
- **Claude.** The journal is read at the start of each session so Claude has the context. Like the rest of your conversation, that text goes to Anthropic under your Claude Code account's terms.
- **Archives.** An archive is saved to your desktop and copied to `~/.scribe/library/`. Nothing is shared unless you send it to someone.

## The background helper

When a session ends, Terminal Scribe starts Claude once more in the background to fill gaps in the journal. It is limited on purpose:

- it can read the finished session's transcript and the files in the project
- it can only create or change files inside the project's `.scribe/` folder
- it cannot run commands or use the web
- anything else it tries is refused automatically

It uses your Claude Code account, so it uses some of your allowance. Turn it off by telling Claude "stop the Terminal Scribe background helper".

When you ask for an archive, Claude reads the journal to write a summary. That run can only read files. It cannot change anything.

## Pausing and turning off

- "Pause journaling" stops all writes for the project, including the background helper, until you say "resume journaling".
- "Turn off journaling here" deletes the project's journal.
- `/plugin uninstall terminal-scribe` stops everything. Journals and the library stay until you delete them.

## Deleting everything

1. In Claude Code, type `/plugin uninstall terminal-scribe`.
2. Delete the `.scribe/` folder in each project.
3. Delete the `~/.scribe/` folder, which holds the library, settings and a log.
