# Vellum

Vellum sets up [Claude Code](https://claude.com/claude-code) on a Mac for running projects. You talk to Claude in plain English and never need to type a command.

It does three things:

- **A brighter Terminal.** Sunny yellow paper, charcoal ink and the [Paper Mono](https://github.com/paper-design/paper-mono) font, made Terminal's default.
- **A journal for every project.** Claude keeps a written history of each project: what you decided and why, what you tried, and what you liked. Ask "where did we get to?" and it knows.
- **A project list with shapes and ports.** Each project gets its own shape and colour in the status line, and its own localhost port, so windows and servers never get mixed up.

Vellum is in beta. Please [report anything odd](https://github.com/jasontheodorou/vellum/issues).

## Install

You need a Mac and [Claude Code](https://claude.com/claude-code) 2.1.292 or later.

Open Terminal, paste this line and press Enter:

```
curl -fsSL https://raw.githubusercontent.com/jasontheodorou/vellum/main/install.sh | bash
```

A new Terminal window opens. Type `claude` in it and say what you want, for example "start a new project called garden planner".

The installer backs up your Claude Code settings first, to `~/.claude/settings.json.before-vellum`. To go back to your old Terminal look, say "go back to my old Terminal theme".

[PRIVACY.md](PRIVACY.md) explains what Vellum records and how to delete it.
