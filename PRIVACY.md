# Privacy and data

Terminal Scribe has no server of its own and sends nothing anywhere itself. Everything it writes stays on your computer.

## What is recorded

When journaling is on for a project, Claude writes notes about your sessions into `.scribe/` in that project:

- a logbook of what happened each day, quoting what you said
- decisions and the reasons for them
- experiments and their results
- lessons, project vocabulary and an overview of where the project stands
- your preferences: what you liked and rejected, in your own words

Claude is told never to copy passwords, API keys, tokens or personal data into the journal, and to describe them instead. That is an instruction to Claude, not a guarantee, so look through a journal before you share it.

## The project list and session notes

- `~/.scribe/projects.tsv` lists each project's name, folder, port, status and the dates it was started and closed.
- While a session runs, `~/.scribe/sessions/` notes which project folders it opened, so the curator knows which journals to organise. Each note is deleted when the session ends.

## Changes outside the journal

Terminal Scribe changes files outside a journal only when you ask:

- "Start a new project" creates the folder, a README, a `.gitignore` and a git repository.
- "Rename" moves the project's folder.
- "Add this folder to my projects", in a project made by the earlier project kit, removes the kit's two hooks from that project's `.claude/settings.json` (keeping `settings.json.kit-backup`) and moves its weekly job to `~/.scribe/retired/`.
- "Stop X" stops the program serving that project's port.
- "Put this on GitHub" creates a repository on your GitHub account and pushes to it.

## Who can see it

- **Git.** The journal is listed in `.git/info/exclude`, which only exists on your computer. It is never committed, and your team's `.gitignore` is not changed.
- **Claude.** The journal is read at the start of each session so Claude has the context. Like the rest of your conversation, that text goes to Anthropic under your Claude Code account's terms.
- **Archives.** An archive is saved to your desktop and copied to `~/.scribe/library/`. Nothing is shared unless you send it to someone.

## The curator

When a session ends, Terminal Scribe makes a condensed copy of the session inside `.scribe/.state/`. It keeps what you and Claude said and a one-line note of each action, and leaves out Claude's private reasoning and the output of tools. It then starts Claude once more in the background to organise the journal. That run is limited on purpose:

- it can read the condensed session and the files in the project
- it can only create or change files inside the project's `.scribe/` folder
- it cannot run commands or use the web
- anything else it tries is refused automatically

The condensed copy is deleted when the curator finishes. The curator's own run is not saved to your Claude Code session history.

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
