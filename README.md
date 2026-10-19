# Vellum

Vellum sets up [Claude Code](https://claude.com/claude-code) on a Mac for running projects. It does three things:

- **A brighter Terminal.** Sunny yellow paper, charcoal ink and the Paper Mono font, made Terminal's default.
- **A journal for every project.** Claude keeps a written history of each one, so every project can learn from the ones before it.
- **A project list with shapes and ports.** Each project gets its own shape and colour in the status line, and its own localhost port, so windows and servers never get mixed up.

Vellum was called Scribe until version 0.10.

After installing, you never need to type a command. You just talk to Claude.

Vellum is in beta (version 0.10). It works, but expect rough edges, and please [report anything odd](https://github.com/jasontheodorou/vellum/issues).

## What you need

- A Mac. Vellum is tested on macOS 26.
- Apple's Command Line Tools. If you are not sure you have them, run `xcode-select --install` in Terminal. It says so if they are already installed.
- [Claude Code](https://claude.com/claude-code) 2.1.292 or later. Run `claude --version` to check, and `claude update` to update it.
- `jq` is optional. Vellum is a little faster with it.

Nothing needs admin rights.

## Install

Open Terminal, paste this line and press Enter:

```
curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash
```

It does four things, then shows a welcome screen:

1. Adds the Vellum profile to Terminal, with the Paper Mono font, and makes it the default.
2. Installs the Claude Code plugin: the journal, the project list, shapes and ports.
3. Sets Claude Code to "Light mode (ANSI colours only)", so Claude draws with Vellum's colours and its text is always readable on the yellow paper.
4. Turns on the status line, and removes Scribe, Vellum's earlier name, if you had it. Your projects, journals and archives are kept.

Your Claude Code settings are backed up first, to `~/.claude/settings.json.before-vellum`. Running the installer again is safe, and it never replaces that first backup. The first time, a new Terminal window opens in Vellum. Type `claude` in it and say what you want.

To install only the journal and the project list, without changing Terminal, run this instead:

```
claude plugin install vellum --marketplace jasontheodorou/vellum
```

That leaves out the status line. To turn it on yourself, add this to `~/.claude/settings.json`, changing the path to wherever the plugin's `bin/vellum` is (or run the installer, which sets up `~/.vellum/bin/vellum` for you):

```
"statusLine": { "type": "command", "command": "/Users/you/.vellum/bin/vellum statusline" }
```

To go back to your old Terminal look and Claude Code's old theme, say "go back to my old Terminal theme", or run `~/.vellum/bin/vellum theme undo`.

## Updates

Claude Code does not update plugins from other people's marketplaces by itself, unless you turn that on. To update Vellum, run:

```
claude plugin update vellum
```

Then restart Claude Code. To have Claude Code update Vellum by itself, type `/plugin` in Claude Code, open the list of marketplaces, choose vellum and turn on auto-update.

To update the Terminal theme and the `~/.vellum/bin/vellum` command as well, run the install command again.

## The Terminal look

Vellum is a brighter take on Terminal's Man Page profile: sunny yellow paper, charcoal ink and crisp accents.

| Part | Colour |
| --- | --- |
| Background | `#FCFCC7` pale lemon |
| Text | `#282923` charcoal, and `#171813` for bold |
| Selection | `#D5E5F5` pale sky blue |
| Cursor | `#3455C5` cobalt blue |
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

- "Pause journaling." before a sensitive conversation, and "Resume journaling." afterwards. While a project is paused, nothing is written to its journal and its conversations are not copied for recall.
- "Tidy the journal."
- "Undo the journal update." puts back the files the curator changed in its last run. It refuses if you have edited those files since, so your own changes are not lost. Ask again to go back one more run.

**Slash commands**

You can also type these in Claude Code:

| Command | What it does |
| --- | --- |
| `/vellum:status` | Says whether this project has a journal, and what it holds |
| `/vellum:pause` | Pauses the journal for this project |
| `/vellum:resume` | Starts the journal again |
| `/vellum:archive` | Saves one summary document of the project to your desktop |
| `/vellum:projects` | Lists your projects, most recent first |
| `/vellum:enable` | Adds this folder to your projects and starts its journal |
| `/vellum:off` | Turns Vellum off for this project and deletes its journal |

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
- **Journal updates.** If the curator changed a journal after your last session, one line says what, such as "Journal updated after your last session: garden-planner, 1 decision, lessons and the overview. Say "undo the journal update" to reverse it."
- **The right port.** Every project has its own port, and Claude uses it when it starts the project's server, so two projects never clash.
- **The status line.** The bottom line shows the project's name in its own colour, next to its own shape (● ◆ ▲ ■ and so on), so several open windows are easy to tell apart. The colours come from your terminal's theme, so they suit your background, and the name is always in your normal text colour. Set `NO_COLOR` to turn colour off. It adds more only when something needs your attention: the server is live, you are on a side branch, commits are waiting to be pushed, or the journal is paused. The installer turns it on, unless you already have a status line of your own.

## Recall: every past conversation

Claude Code saves every conversation on your Mac, but nothing searches them. Vellum does. Ask about anything you discussed, in any project, and Claude finds the conversation, the date and your exact words, then reads more if it needs to.

The first search reads your history for up to a minute, then answers from what it has read. Later searches carry on where it stopped. After that each conversation is added as it ends. Each copy is about a hundredth of the size of the original. Curator runs are left out, and so are conversations in projects where the journal is paused or was turned down.

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

Claude's notes during a session cost very little. The curator runs Claude once more when each session ends, in the background, usually for between 30 seconds and a few minutes. It reads a condensed copy of the session, about a hundredth of the full record. It still uses some of your plan's allowance or your API credit.

To save money, say "use Haiku for Vellum". To turn the curator off, say "stop the background curator".

## Start Claude in your home folder

Start Claude in your home folder (just open Terminal and type `claude`). Claude Code lets Claude edit files without asking only inside the folder it started in. Starting at home covers every project in `~/projects`.

## Uninstall

1. Run `~/.vellum/bin/vellum theme undo`. This puts back your old Terminal profile and Claude Code's old theme.
2. Type `/plugin uninstall vellum` in Claude Code. This stops the journal, the project list and recall.

Your projects, journals and library are not deleted, because they are your work. Some other things also stay until you remove them:

- **Claude Code's theme.** If you skipped step 1, Claude Code stays on "Light mode (ANSI colours only)". Type `/config` in Claude Code to choose another theme.
- **The status line.** Delete the `statusLine` entry from `~/.claude/settings.json`. Or put back the whole file from `~/.claude/settings.json.before-vellum`, which is how it was before you installed Vellum. That also removes any settings you changed since.
- **The Vellum Terminal profile.** In Terminal, open Settings, then Profiles, choose Vellum and click the minus button. Choose another profile as the default first.
- **The Paper Mono font.** Open Font Book, find Paper Mono, and remove it.
- **Vellum's own files.** Delete the `~/.vellum` folder. [PRIVACY.md](PRIVACY.md) lists what is in it.

## Works on

macOS only. It uses tools every Mac already has, plus Apple's Command Line Tools. It uses `gh` (GitHub's command line tool) only to put projects on GitHub.

## Coming from Scribe or the Claude Project Kit

Vellum was called Scribe until version 0.10. The installer moves you over:

- **The Scribe plugin.** The installer removes it. Vellum moves Scribe's data from `~/.scribe` to `~/.vellum` the first time it runs, and moves each project's `.scribe/` journal to `.vellum/` the next time you open it. Nothing is lost.
- **The first Scribe, installed with a different `curl` command into `~/.scribe`.** The installer removes it and keeps your archived projects. If you installed only the plugin, Claude notices the old version and offers to remove it. Projects with an old `journal/` folder can be moved to `.vellum/` when you open them.

If you used the earlier Claude Project Kit, say "import my projects". Every project keeps its `design-journal/` folder, its training manual and its port. When you open a kit project, Claude offers to switch it over fully. That removes the kit's own hooks from the project, keeping a backup, and stops its weekly job, because Vellum now does both.

## Contributing

Bug reports and improvements are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) explains how to run the tests. Report security problems as [SECURITY.md](SECURITY.md) describes, not in a public issue.

## Licence

Vellum is under the [MIT licence](LICENSE). Copyright 2026 Jason Theodorou.

The Paper Mono font in `theme/fonts` is not under the MIT licence. It is © 2025 The Paper Mono Project Authors, under the [SIL Open Font License 1.1](theme/fonts/OFL.txt).
