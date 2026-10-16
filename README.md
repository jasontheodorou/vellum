# Terminal Scribe

![Terminal Scribe](scribe_logo_001.png)

Terminal Scribe is a plugin for [Claude Code](https://claude.com/claude-code). It writes and organises a plain-English history of your project, so you never have to take notes, and every project can learn from the ones before it.

## What it does

Claude Code remembers some facts about you. Git remembers what changed. Neither keeps the reasons, the options you turned down, what failed or what you said when you saw the result. Terminal Scribe keeps all of that.

At the end of every session, a curator reads the conversation and organises the journal:

- **A logbook** of what was asked, what was done, what went wrong and how it ended, in plain English, with your own words quoted.
- **Decisions** with the options considered, the reasons and the consequences. When a decision replaces an earlier one, the old one is marked and linked.
- **Experiments**, including the ones that failed, so the same mistake is not made twice.
- **Lessons**, sorted by topic and written so they make sense in any project.
- **Your preferences**: what you liked, rejected and asked for every time, in your words.
- **An overview** that is rewritten every session, so it always says where things stand today, what is open and what is next.
- **A weekly round-up**, and an index of every entry with a one-line summary.

Claude reads the overview, your preferences and the index at the start of every session, so it picks up where you left off without being told.

## Why it matters

- **No note-taking.** You keep working. The record writes itself.
- **A clean handoff.** Say "archive this project" and you get one document to send to a stakeholder or keep for a portfolio.
- **Projects learn from each other.** Ask "have we faced this before?" and Claude searches your past projects. Point a new project at an old one and it starts with that project's lessons.
- **Private by default.** The journal stays on your computer and is kept out of git.
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
- "Tidy the journal." This runs the curator straight away.
- "Archive this project."
- "Have we faced this kind of problem before?"
- "Bring in what we learned on the website project."
- "Turn off journaling here." This deletes the journal, so Claude asks you to confirm.

There are also slash commands: `/terminal-scribe:status`, `/terminal-scribe:pause`, `/terminal-scribe:resume`, `/terminal-scribe:archive`, `/terminal-scribe:enable` and `/terminal-scribe:off`.

## What it costs

Claude jots notes in the journal during your session, which costs very little.

When a session ends, the curator runs Claude once more, in the background, to organise the journal. It reads a condensed copy of the session, usually about a hundredth of the full record, so it costs much less than the session itself. It typically takes one to three minutes. It still uses some of your plan's allowance or your API credit. To turn it off, tell Claude "stop the Terminal Scribe background helper".

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
