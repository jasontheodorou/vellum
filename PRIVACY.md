# Privacy and data

Vellum has no server of its own. It never sends anything anywhere by itself. Everything it writes stays on your computer. Some of it is read by Claude, and Claude runs on Anthropic's servers, so that text goes to Anthropic. [What goes to Anthropic](#what-goes-to-anthropic) lists when.

## What is recorded

When journaling is on for a project, Claude writes notes about your sessions into `.vellum/` in that project:

- a logbook of what happened each day, quoting what you said
- decisions and the reasons for them
- experiments and their results
- lessons, project vocabulary and an overview of where the project stands
- your preferences: what you liked and rejected, in your own words

Claude is told never to copy passwords, API keys, tokens or personal data into the journal, and to describe them instead. That is an instruction to Claude, not a guarantee, so look through a journal before you share it.

Vellum also keeps these files in the journal:

- `.vellum/.state/` holds a copy of the journal from before each curator run, so "undo the journal update" can put it back, and a record of which files each run changed.
- `.vellum/.state/helper.log` notes when the curator ran and what it changed.
- `.vellum/.imports` lists the other projects you asked Claude to bring lessons in from.

## Recall

To search past conversations, Vellum makes a condensed copy of each conversation Claude Code has saved in `~/.claude/projects/`. A copy is made the first time you search, and then again at the end of every session. Each copy keeps what you and Claude said and a one-line note of each action, as the curator's copy does (see [The curator](#the-curator)). The copies are kept in `~/.vellum/recall/`, about a hundredth of the size of the originals.

Conversations in projects where the journal is paused, or where you said no to a journal, are not copied. Curator runs are not copied either.

Delete `~/.vellum/recall/` at any time. It is rebuilt the next time you search.

## Everything in ~/.vellum

| What | Where |
| --- | --- |
| The project list: each project's name, folder, port, status and the dates it was started and closed | `~/.vellum/projects.tsv` |
| Archived projects | `~/.vellum/library/` |
| Your settings | `~/.vellum/config` |
| Folders where you said no to a journal | `~/.vellum/declined` |
| Recall copies | `~/.vellum/recall/` |
| One-line messages about the curator's last run, shown at the start of your next session and then deleted | `~/.vellum/notices/` |
| Which project folders a running session opened, so the curator knows which journals to organise. Each note is deleted when the session ends | `~/.vellum/sessions/` |
| Sessions waiting for the curator, and its lock | `~/.vellum/.state/` |
| A short-lived note of which ports are in use, for the status line | `~/.vellum/.cache/` |
| A log of what Vellum did | `~/.vellum/vellum.log` |
| Which Terminal profile was the default before Vellum, and which version of the Vellum profile is installed | `~/.vellum/theme-*` |
| The helper the installer adds, which runs the newest installed copy of the plugin | `~/.vellum/bin/vellum` |
| The weekly jobs of projects from the earlier Claude Project Kit, once switched over | `~/.vellum/retired/` |

## What goes to Anthropic

Text Claude reads is sent to Anthropic under your Claude Code account's terms, like the rest of your conversation. With Vellum, that includes:

- **At the start of a session:** the project's overview, preferences, lesson titles and journal index. In your home folder, it is the project list instead.
- **During a session:** anything Claude reads to answer you, including journal files and the results of a recall search.
- **When a session ends:** the curator starts Claude with the condensed copy of the session, and Claude reads any journal and project files it needs to organise the journal.
- **When you ask for an archive:** Claude reads the journal to write a summary.

## The curator

When a session ends, Vellum hands the work to the curator, which carries on in the background after Claude Code has closed. It makes a condensed copy of the session inside `.vellum/.state/`. The copy keeps what you and Claude said and a one-line note of each action. It leaves out Claude's private reasoning and the output of tools.

The one-line note of each action keeps up to 200 characters of it, such as a file name or the command Claude ran. When an action failed, up to 300 characters of the error are kept too. A command can contain a secret, such as `export API_KEY=...`, so that secret can end up in the condensed copy, in recall and in what the curator sends to Anthropic. Avoid typing secrets into commands Claude runs, or pause journaling first.

The curator then starts Claude once more to organise the journal. That run is limited on purpose:

- it can read the condensed session and the files in the project
- it can only create or change files inside the project's `.vellum/` folder
- it cannot run commands or use the web
- anything else it tries is refused automatically

The condensed copy is deleted when the curator finishes. The curator's own run is not saved to your Claude Code session history.

It uses your Claude Code account, so it uses some of your allowance. Turn it off by telling Claude "stop the background curator".

When you ask for an archive, Claude reads the journal to write a summary. That run can only read files. It cannot change anything.

## Changes outside the journal

The installer changes these things:

- **Claude Code's settings.** It sets `theme` to "Light mode (ANSI colours only)" and adds a `statusLine` in `~/.claude/settings.json`. It keeps a copy of the file as it was first, in `~/.claude/settings.json.before-vellum`, and never replaces that copy.
- **Fonts.** It copies Paper Mono into `~/Library/Fonts`.
- **Terminal.** It adds the Vellum profile and makes it the default for new windows.
- **The old Scribe.** If the first Scribe is still installed, it removes Scribe's hooks from `~/.claude/settings.json` (keeping a backup) and the line Scribe added to `~/.zshrc`, `~/.bashrc` or `~/.bash_profile`.

`vellum theme undo` puts back the Terminal profile and Claude Code's theme. [The README](README.md#uninstall) explains how to remove the rest.

While Claude Code runs, Vellum sets `PORT` to the project's port for the commands Claude runs, so servers start on the right port. It does not change your shell.

Otherwise, Vellum changes files outside a journal only when you ask:

- "Start a new project" creates the folder, a README, a `.gitignore` and a git repository.
- "Rename" moves the project's folder.
- "Add this folder to my projects", in a project made by the earlier Claude Project Kit, removes the kit's two hooks from that project's `.claude/settings.json` (keeping `settings.json.kit-backup`) and moves its weekly job to `~/.vellum/retired/`.
- "Stop X" stops the program serving that project's port.
- "Put this on GitHub" creates a repository on your GitHub account and pushes to it.

## Who can see it

- **Git.** The journal is listed in `.git/info/exclude`, which only exists on your computer. It is never committed, and your team's `.gitignore` is not changed.
- **Anthropic.** Only what Claude reads, as described above.
- **Archives.** An archive is saved to your desktop and copied to `~/.vellum/library/`. Nothing is shared unless you send it to someone.

## Pausing and turning off

- "Pause journaling" stops all writes for the project, including the curator, and stops its conversations being copied for recall, until you say "resume journaling".
- "Turn off journaling here" deletes the project's journal. If the journal is tracked by git, Vellum refuses, so a journal your team shares is not deleted by accident.
- `/plugin uninstall vellum` stops everything. Journals and the library stay until you delete them.

## Deleting everything

1. Run `~/.vellum/bin/vellum theme undo`, then type `/plugin uninstall vellum` in Claude Code.
2. Delete the `.vellum/` folder in each project.
3. Delete the `~/.vellum/` folder.
4. Remove the rest as [the README](README.md#uninstall) explains: the status line, the Terminal profile and Paper Mono.
