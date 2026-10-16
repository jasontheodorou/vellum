# Contributing

Thank you for helping. Bug reports, ideas and pull requests are all welcome.

## How it fits together

| Path | What it does |
| --- | --- |
| `.claude-plugin/plugin.json` | The plugin's name, version and description |
| `.claude-plugin/marketplace.json` | Lets people install the plugin from this repository |
| `hooks/hooks.json` | Runs `scribe hook session-start` and `scribe hook session-end` |
| `bin/scribe` | Every command and both hooks, in one bash script |
| `templates/instructions.md` | What Claude is told at the start of a session |
| `templates/curator.md` | What the curator is told at the end of a session |
| `templates/condense.jq` | Shrinks a session record for the curator (the script has a Python copy for computers without jq) |
| `templates/journal-seed/` | The files a new journal starts with |
| `skills/` | The `/terminal-scribe:` slash commands |
| `test/` | Automated tests, and the manual test in `SMOKE-TEST.md` |

`bin/scribe` must run on bash 3.2, which is the version macOS ships. That means no associative arrays, no `${var,,}` and no `mapfile`.

## Running the plugin from your copy

```
claude --plugin-dir /path/to/terminal-scribe
```

Uninstall the released plugin first, or both copies will run.

## Running the tests

Install [bats](https://github.com/bats-core/bats-core) and [ShellCheck](https://www.shellcheck.net), then run:

```
bats test/
shellcheck -S warning bin/scribe test/helpers.bash
claude plugin validate . --strict
```

Each test runs in a throwaway home folder, so your own `~/.scribe` and `~/.claude` are never touched. Tests use a fake `claude`, so they cost nothing.

In a bats test, write `refute grep ...` rather than `! grep ...`. Bats ignores a failed `!` line unless it is the last line of the test.

## Before you open a pull request

- Add or change a test for what you changed.
- Update `CHANGELOG.md` under the unreleased version.
- Run the manual test in `test/SMOKE-TEST.md` if you changed a hook, the instructions or the curator.
- If you change `templates/condense.jq`, make the same change to the Python copy in `bin/scribe`. A test checks they agree.
- Write anything people will read in plain English, and use short sentences.

## Releasing

1. Update `version` in `.claude-plugin/plugin.json` and the heading in `CHANGELOG.md`.
2. Merge to `main`. Installed copies update to the new version.
3. Tag the release, such as `v1.0.0`, and publish it on GitHub with the changelog entry.
