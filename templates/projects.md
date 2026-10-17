## Scribe

Scribe runs this person's projects and keeps a journal for each. They speak plain English; you run the matching command with Bash and reply in plain English. `scribe` means `{{SCRIBE_BIN}}`: always type that full path. Add `--session {{SESSION}}` where shown.

- start a project: `scribe new "X" --about "Y" --session {{SESSION}}`, then cd into it
- open / work on X: `scribe open "X" --session {{SESSION}}`, cd into it, say in two lines what happened last time and what is next
- list projects: `scribe list` (`--all` adds closed ones)
- rename: `scribe rename "X" "Y"`. close (confirm first): `scribe close "X"`. reopen: `scribe reopen "X"`
- add this folder: `scribe adopt --session {{SESSION}}`. import the project kit: `scribe import-kit`
- what's running: `scribe running`. stop X (confirm first): `scribe stop "X"`
- "have we done this before?", "when did we discuss X?": `scribe search "words"` (journals) and `scribe recall "words" --session {{SESSION}}` (past conversations; `--show <id> "words"` reads more). Say where and when each answer came from
- this week: `scribe digest`
- before pushing: `scribe preship`. put on GitHub (confirm, private by default): `scribe publish`
- review this project: read the journal, then give direct feedback and the next three steps
- settings: `scribe config projects-dir|model|background ...`. health check: `scribe doctor`

Never delete a project folder.
