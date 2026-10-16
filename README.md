# Terminal Scribe

![Terminal Scribe](scribe_logo_001.png)

Terminal Scribe is a plugin for [Claude Code](https://claude.com/claude-code). It keeps a plain-English journal of your project as you work, so Claude remembers what you decided, what you tried and where you left off.

## Why use it

- **No note-taking.** Every session adds to the journal: what you talked about, what you decided and what you tried. You do not have to write anything.
- **Pick up where you left off.** Claude reads the journal at the start of every session, so you never have to explain where you got to.
- **A clean handoff.** Say "archive this project" and Claude saves one tidy document to your desktop, with the summary, the decisions and the lessons.
- **Lessons that carry over.** Archived projects go into a library on your computer. On a new project, ask "have we faced this before?" and Claude searches it.
- **Private by default.** The journal stays on your computer. It is kept out of git, so it is never committed or shared by accident.
- **You are in control.** Say "pause journaling" before a sensitive conversation, and "resume journaling" afterwards.

## Install

You need Claude Code 2.1.275 or later. In Claude Code, type:

```
/plugin install terminal-scribe --marketplace jasontheodorou/terminal-scribe
```

On older versions, type these two lines instead:

```
/plugin marketplace add jasontheodorou/terminal-scribe
/plugin install terminal-scribe@terminal-scribe
```

Then open Claude Code in a project folder. Claude asks once whether to keep a journal for that project. Say yes.

## Using it

Keep working as you normally do. When you want something from the journal, ask in plain English:

- "What did we decide about the navigation last week?"
- "Summarise what we have done on this project."
- "Pause journaling." and "Resume journaling."
- "Archive this project."
- "Have we faced this kind of problem before?"
- "Bring in what we learned on the website project."
- "Turn off journaling here." This deletes the journal, so Claude asks you to confirm.

There are also slash commands: `/terminal-scribe:status`, `/terminal-scribe:pause`, `/terminal-scribe:resume`, `/terminal-scribe:archive`, `/terminal-scribe:enable` and `/terminal-scribe:off`.

## What it costs

Claude writes most of the journal during your session, which costs very little.

When a session ends, a background helper runs Claude once more to fill in anything that was missed. That uses some of your plan's allowance or your API credit. To turn it off, tell Claude "stop the Terminal Scribe background helper".

To save money, tell Claude "use Haiku for Terminal Scribe". The helper and archive summaries then use that cheaper model.

## Where things are kept

| What | Where |
| --- | --- |
| A project's journal | `.scribe/` in the project folder |
| Archived projects | `~/.scribe/library/` |
| Settings | `~/.scribe/config` |
| An archive you asked for | Your desktop |

[PRIVACY.md](PRIVACY.md) explains what is recorded, what the background helper can and cannot do, and how to delete everything.

## Upgrading from the curl installer

Versions before 1.0 were installed by pasting a `curl` command into Terminal. After you install the plugin, Claude notices the old version and offers to remove it. Your archived projects are kept. You can also ask Claude to "remove the old Terminal Scribe install".

Projects that already have a `journal/` folder can be moved to the new layout. Claude offers this when you open the project, or you can ask Claude to "migrate this project's journal". It moves the journal to `.scribe/` and removes the Terminal Scribe section from `CLAUDE.md` and the `journal/` line from `.gitignore`.

## Uninstall

In Claude Code, type `/plugin uninstall terminal-scribe`.

That stops all journaling. It does not delete your journals or your library, because they are your work. To delete them as well, remove each project's `.scribe/` folder and the `~/.scribe/` folder.

## Works on

macOS, Linux and Windows through WSL. It needs bash, which these systems already have. It uses `jq` or `python3` if they are installed, but does not need them.

## Contributing

Bug reports and improvements are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains how to run the tests. Report security problems as [SECURITY.md](SECURITY.md) describes, not in a public issue.

## Licence

[MIT](LICENSE). Copyright 2026 Jason Theodorou.
