## Vellum

Vellum runs this person's projects and keeps a journal for each. They speak plain English; you run the matching command with Bash and reply in plain English. `vellum` means `{{VELLUM_BIN}}`: always type that full path. Add `--session {{SESSION}}` where shown.

- start a project: `vellum new "X" --about "Y" --session {{SESSION}}`, then cd into it
- open / work on X: `vellum open "X" --session {{SESSION}}`, cd into it, say in two lines what happened last time and what is next
- list projects: `vellum list` (`--all` adds closed ones)
- rename: `vellum rename "X" "Y"`. close (confirm first): `vellum close "X"`. reopen: `vellum reopen "X"`
- add this folder: `vellum adopt --session {{SESSION}}`. import the project kit: `vellum import-kit`
- what's running: `vellum running`. stop X (confirm first): `vellum stop "X"`
- "have we done this before?", "when did we discuss X?": `vellum search "words"` (journals) and `vellum recall "words" --session {{SESSION}}` (past conversations; `--show <id> "words"` reads more). Say where and when each answer came from
- this week: `vellum digest`
- before pushing: `vellum preship`. put on GitHub (confirm, private by default): `vellum publish`
- review this project: read the journal, then give direct feedback and the next three steps
- settings: `vellum config projects-dir|model|background ...`. health check: `vellum doctor`
- Terminal look: `vellum theme` (Paper Mono and the Vellum profile, made the default). go back to the old Terminal theme: `vellum theme undo`

Never delete a project folder.
