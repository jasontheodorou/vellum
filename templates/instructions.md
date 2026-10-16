## Terminal Scribe is keeping a journal for this project

The journal is in `.scribe/` at the project root. Only this person's computer has it: it is excluded from git, so it is never committed or shared.

Before any journal write, check that `.scribe/.paused` does not exist. If it does, write nothing to the journal this session.

As you work, keep these files up to date in plain English:

- `.scribe/logbook/YYYY-MM-DD.md` is a running, chronological account of today's session.
- `.scribe/decisions/NNN-slug.md` records a real decision (Context, Decision, Why, Consequences). Number them in order. Casual discussion is not a decision.
- `.scribe/lessons.md` holds lessons worth keeping. Ask: "would someone joining this project in six months thank me for this?" Leave out filler.
- `.scribe/experiments/YYYY-MM-DD-slug.md` records something tried, with its hypothesis and outcome. Include failures.
- `.scribe/glossary.md` defines words that have a special meaning in this project.
- A themed file at `.scribe/` (such as `bugs.md`) is fine when a topic keeps coming back.

Start every file with YAML frontmatter: `id`, `type`, `date`, `topic`, `tags`, `status`, `related`.

Never copy passwords, API keys, tokens or personal data into the journal. Describe them instead ("rotated the staging API key").

Write as you go. When the session ends, a background helper reads the conversation and fills in anything you missed.

When the person asks what was decided, learned or done ("what did we decide about X?", "what did I do yesterday?", "summarise the project"), read the journal and answer in the chat. They should never need to open the files. For "have we faced this before?", also search the archive of past projects at `~/.scribe/library/`.

The person controls the journal in plain English. Run these with Bash. In each one, `scribe` stands for this plugin's copy, `{{SCRIBE_BIN}}`; always type that full path, because another program called `scribe` may come first on the PATH.

- "pause journaling": `scribe pause`. "resume journaling": `scribe resume`.
- "is journaling on?": `scribe status`.
- "archive this project" or "wrap this up": `scribe archive`, then say where the file was saved.
- "bring in what we learned on project X": `scribe link X`. To undo: `scribe unlink X`.
- "stop the background helper": `scribe config background off`. To restart it: `scribe config background on`.
- "use a cheaper model" (or a named one): `scribe config model haiku`. Back to the usual model: `scribe config model default`.
- "remove the old install": `scribe remove-old-install`. "migrate this project's journal": `scribe migrate`.
- "turn off journaling here": confirm first, because it deletes the journal, then run `scribe off --yes`.
