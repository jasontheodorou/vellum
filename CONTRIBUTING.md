# Contributing

Thank you for helping. Bug reports, ideas and pull requests are all welcome.

## How it fits together

| Path | What it does |
| --- | --- |
| `.claude-plugin/plugin.json` | The plugin's name, version and description |
| `.claude-plugin/marketplace.json` | Lets people install the plugin from this repository |
| `install.sh` | The one-line installer: the plugin, the Terminal theme, Claude Code's theme and the status line |
| `hooks/hooks.json` | Runs `vellum hook session-start` and `vellum hook session-end` |
| `bin/vellum` | The command Claude runs. It loads the files in `lib/` |
| `lib/common.sh` | Shared helpers, settings and which folder holds a project's journal |
| `lib/journal.sh` | The journal: starter files, the index, the curator and journal commands |
| `lib/projects.sh` | The project list and the project commands |
| `lib/recall.sh` | Recall: condensing and searching past conversations |
| `lib/hooks.sh` | What Claude is told when a session starts, and the curator run when it ends |
| `lib/theme.sh` | `vellum theme`, `vellum theme undo` and the welcome screen |
| `theme/` | The Vellum Terminal profile, the script that builds it, and the Paper Mono font (under the SIL Open Font License) |
| `templates/projects.md` | What Claude is told in every session about handling projects |
| `templates/instructions.md` | What Claude is told about keeping a project's journal |
| `templates/curator.md` | What the curator is told at the end of a session |
| `templates/condense.jq` | Shrinks a session record for the curator (the script has a Python copy for computers without jq) |
| `templates/journal-seed/` | The files a new journal starts with |
| `skills/` | The `/vellum:` slash commands |
| `test/` | Automated tests, and the manual test in `SMOKE-TEST.md` |
| `site/` | The Vellum website. It is not part of the plugin's behaviour |

The scripts must run on bash 3.2, which is the version macOS ships. That means no associative arrays, no `${var,,}` and no `mapfile`.

## Running the plugin from your copy

```
claude --plugin-dir /path/to/vellum
```

Uninstall the released plugin first, or both copies will run.

## Running the tests

Install [bats](https://github.com/bats-core/bats-core) and [ShellCheck](https://www.shellcheck.net), then run:

```
bats test/
shellcheck -x -P SCRIPTDIR -S warning bin/vellum install.sh test/helpers.bash
claude plugin validate . --strict
```

The `-x` option makes ShellCheck follow `bin/vellum` into every file in `lib/`, so this checks all of them. Checking a `lib/` file on its own gives false warnings, because its variables are used in other files.

Each test runs in a throwaway home folder, so your own `~/.vellum` and `~/.claude` are never touched. Tests use a fake `claude`, so they cost nothing.

In a bats test, write `refute grep ...` rather than `! grep ...`, and end every `[[ ... ]]` check with `|| false`. On the bash 3.2 that macOS ships, bats ignores a failed `!` or `[[ ]]` line unless it is the last line of the test.

## Before you open a pull request

- Add or change a test for what you changed.
- Update `CHANGELOG.md` under the unreleased version.
- Run the manual test in `test/SMOKE-TEST.md` if you changed a hook, the instructions or the curator.
- If you change `templates/condense.jq`, make the same change to the Python copy in `lib/journal.sh`. A test checks they agree.
- Write anything people will read in plain English, and use short sentences.

## Releasing

1. Update `version` in `.claude-plugin/plugin.json` and the heading in `CHANGELOG.md`.
2. Merge to `main`. People get the new version when they run `claude plugin update vellum` or the installer again. Claude Code only updates it by itself for people who turned on auto-update for the vellum marketplace.
3. Tag the release, such as `v1.0.0`, and publish it on GitHub with the changelog entry.
