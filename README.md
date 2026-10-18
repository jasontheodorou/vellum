# Vellum

Vellum sets up [Claude Code](https://claude.com/claude-code) on a Mac for running projects. It does three things:

- **A brighter Terminal.** Sunny yellow paper, charcoal ink and the Paper Mono font, made Terminal's default.
- **A journal for every project.** Claude keeps a written history of each one, so every project can learn from the ones before it.
- **A project list with shapes and ports.** Each project gets its own shape and colour in the status line, and its own localhost port, so windows and servers never get mixed up.

Vellum was called Scribe until version 0.10.

You never type a command. You just talk to Claude.

Vellum is in beta (version 0.10). It works, but expect rough edges, and please [report anything odd](https://github.com/jasontheodorou/vellum/issues).

## Install

You need [Claude Code](https://claude.com/claude-code) first. Then open Terminal, paste this line and press Enter:

```
curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash
```

It does four things, then shows a welcome screen:

1. Adds the Vellum profile to Terminal, with the Paper Mono font, and makes it the default.
2. Installs the Claude Code plugin: the journal, the project list, shapes and ports.
3. Sets Claude Code to "Light mode (ANSI colours only)", so Claude draws with Vellum's colours and its text is always readable on the yellow paper.
4. Turns on the status line, and removes Scribe, Vellum's earlier name, if you had it. Your projects, journals and archives are kept.

Your Claude Code settings are backed up first, and running it again is safe. A new Terminal window opens in Vellum. Type `claude` in it and say what you want.

To install only the journal and the project list, without changing Terminal, run this instead:

```
claude plugin install vellum --marketplace jasontheodorou/vellum
```

Nothing needs admin rights. To go back to your old Terminal look, say "go back to my old Terminal theme", or run `~/.vellum/bin/vellum theme undo`.

## The Terminal look

Vellum is a brighter take on Terminal's Man Page profile: sunny yellow paper, charcoal ink and crisp accents.

| Part | Colour |
| --- | --- |
| Background | `#FCFCC7` pale lemon |
| Text | `#282923` charcoal, and `#171813` for bold |
| Selection | `#D5E5F5` pale sky blue |
| Cursor | `#B53668` raspberry |
| Accents | `#B63E32` red, `#347348` green, `#876000` amber, `#3455C5` cobalt blue, `#B53668` raspberry, `#21717A` teal |
| Bright accents | `#B04A1E` Claude orange, `#2B6A3D` green, `#7A5600` amber, `#2C47AE` blue, `#9E2D5B` berry, `#1B6670` teal, `#66655A` grey |
| Light colours | `#FFFADB` cream and `#FFFFFF` white, for Claude's message backgrounds |

The font is [Paper Mono](https://github.com/paper-design/paper-mono) at 18 point. Vellum sets all 16 terminal colours, because Claude Code's ANSI-only theme uses every one of them. Every colour used for text has at least 4.5 to 1 contrast against the background; white and bright white stay light, because Claude uses them for message backgrounds. The profile is for Apple's own Terminal app.

## What you can say

**Start, open and finish projects**

- "Start a new project called garden planner, for planning a vegetable garden."
- "Open garden planner." or "Let's work on the patio."
- "What projects do I have?"
- "Rename patio to back garden."
- "We're done with the patio." Claude saves a final write-up to your desktop and closes it. Nothing is deleted.
- "Reopen the patio."
- "Add this folder to my projects."

**Ask about your work**

- "Where did we get to?"
- "What did we decide about the soil, and why?"
- "Have I dealt with drainage in any other project?"
- "Why did we drop the Priorities page, and what did I say about it?" Claude searches every Claude Code conversation you have ever had, not just the journals.
- "What did I do this week?"
- "Review this project." Claude gives you direct feedback and the next three things to do.
- "Bring in what we learned on the patio project."

**Share your work**

- "Archive this project." You get one tidy document on your desktop to send to a stakeholder or keep for a portfolio.
- "Is it safe to push?" Claude checks for passwords, keys and private files before code leaves your Mac.
- "Put this on GitHub." It is private unless you say otherwise.

**Running things**

- "What's running?" and "Stop garden planner."

**Control the journal**

- "Pause journaling." before a sensitive conversation, and "Resume journaling." afterwards.
- "Tidy the journal."

## How the journal works

Every project gets a journal. While you work, Claude notes what happens. When you finish a session, a curator reads the conversation and organises the journal:

- **A logbook** of what was asked, what was done, what went wrong and how it ended, with your own words quoted.
- **Decisions**, with the options considered, the reasons and the consequences. When a decision replaces an earlier one, the old one is marked and linked.
- **Experiments**, including the ones that failed, so the same mistake is not made twice.
- **Lessons**, sorted by topic and written so they make sense in any project.
- **Your preferences**: what you liked, rejected and asked for every time, in your words.
- **An overview** that is rewritten after every session, so it always says where things stand, what is open and what is next.
- **A weekly round-up**, and an index of every entry with a one-line summary.

Claude reads the overview, your preferences and the index whenever you open a project, so it picks up where you left off without being told.

## Small things that just happen

- **Last time.** When you start Claude in a project, one line reminds you where you were, such as "Last time, 16 Oct: chose raised beds. Next: confirm bed sizes."
- **Journal updates.** If the curator changed a journal after your last session, one line says what, such as "sanctum: 1 decision, lessons and the overview."
- **The right port.** Every project has its own port, and Claude uses it when it starts the project's server, so two projects never clash.
- **The status line.** The bottom line shows the project's name in its own colour, next to its own shape (● ◆ ▲ ■ and so on), so several open windows are easy to tell apart. The colours come from your terminal's theme, so they suit your background, and the name is always in your normal text colour. Set `NO_COLOR` to turn colour off. It adds more only when something needs your attention: the server is live, you are on a side branch, commits are waiting to be pushed, or the journal is paused. The installer turns it on, unless you already have a status line of your own.

## Recall: every past conversation

Claude Code saves every conversation on your Mac, but nothing searches them. Vellum does. Ask about anything you discussed, in any project, and Claude finds the conversation, the date and your exact words, then reads more if it needs to.

The first search reads your history once, which takes a minute or two. After that each conversation is added as it ends. Background helper runs are left out.

Claude Code remembers some facts about you, and git remembers what changed. Neither keeps the reasons, the options you turned down, what failed or what you said when you saw the result. The journal keeps all of that.

## Where things are kept

| What | Where |
| --- | --- |
| Your projects | `~/projects`, unless you say "change where projects go" |
| A project's journal | `.vellum/` inside the project, kept out of git |
| The list of projects | `~/.vellum/projects.tsv` |
| Archived projects | `~/.vellum/library/` |
| Settings | `~/.vellum/config` |
| Write-ups you ask for | Your desktop |

[PRIVACY.md](PRIVACY.md) explains what is recorded, what the curator can and cannot do, and how to delete everything.

## What it costs

Claude's notes during a session cost very little. The curator runs Claude once more when each session ends, in the background, usually for under a minute to a few minutes. It reads a condensed copy of the session, about a hundredth of the full record. It still uses some of your plan's allowance or your API credit.

To save money, say "use Haiku for Vellum". To turn the curator off, say "stop the background curator".

## Start Claude in your home folder

Start Claude in your home folder (just open Terminal and type `claude`). Claude Code lets Claude edit files without asking only inside the folder it started in. Starting at home covers every project in `~/projects`.

## Coming from the project kit

If you used the earlier project kit, say "import my projects". Every project keeps its `design-journal/` folder, its training manual and its port. When you open a kit project, Claude offers to switch it over fully. That removes the kit's own hooks from the project, keeping a backup, and stops its weekly job, because Vellum now does both.

## Coming from the old Scribe curl installer

The first versions of Scribe were installed with a different `curl` command into `~/.scribe`. After you install the plugin, Claude notices the old version and offers to remove it. Your archived projects are kept. Projects with an old `journal/` folder can be moved to `.vellum/` when you open them.

## Coming from Scribe

Vellum moves Scribe's data from `~/.scribe` to `~/.vellum` the first time it runs, and moves each project's `.scribe/` journal to `.vellum/` the next time you open it. Nothing is lost. Uninstall the Scribe plugin with `/plugin uninstall scribe`.

## Uninstall

In Claude Code, type `/plugin uninstall vellum`. To put back your old Terminal profile first, run `~/.vellum/bin/vellum theme undo`.

That stops everything. It does not delete your projects, journals or library, because they are your work.

## Works on

macOS only, with Claude Code 2.1.292 or later. It uses tools every Mac already has. It uses `gh` (GitHub's command line tool) only to put projects on GitHub.

## Contributing

Bug reports and improvements are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains how to run the tests. Report security problems as [SECURITY.md](SECURITY.md) describes, not in a public issue.

## Licence

[MIT](LICENSE). Copyright 2026 Jason Theodorou.
