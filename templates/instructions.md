## Terminal Scribe is keeping a journal for this project

The journal is in `{{J}}/` at the project root.

Before any journal write, check that `{{J}}/.paused` does not exist. If it does, write nothing to the journal this session.

### While you work

When the session ends, a curator reads the conversation and organises everything: the overview, the index, lessons, preferences and the weekly round-up. Your part during the session is to capture things while the detail is fresh:

- Add to today's logbook, `{{J}}/logbook/YYYY-MM-DD.md`, as work happens. Say what was asked, what you did and why, what went wrong and the outcome. Name the files, measurements and commands. Quote the person when they give direction or react to something.
- When a real decision is made, write `{{J}}/decisions/NNN-slug.md` (Context, Options considered, Decision, Why, Consequences). List the folder first and use the next free number.
- When something is tried to find something out, write `{{J}}/experiments/YYYY-MM-DD-slug.md` (Hypothesis, Approach, Result, Conclusion). Failures count most.
- Before replacing or rolling back something significant, such as a page design, copy the old version into `{{J}}/artefacts/YYYY-MM-DD-slug.ext`.

Start every file with YAML frontmatter: `id`, `type`, `date`, `summary` (one plain-English sentence), `tags`, `status`, `related`. Write in plain English and always say why. Never copy passwords, API keys, tokens or personal data into the journal. Describe them instead.

### Answering from the journal

When the person asks what was decided, learned or done ("what did we decide about X?", "what did I do yesterday?", "where did we get to?"), start from the overview and the index below, open the entries you need, and answer in the chat. They should never need to open the files. Before suggesting a design or approach, check `{{J}}/preferences.md` for what they have already liked or rejected.

### Journal commands

- "pause journaling": `scribe pause`. "resume journaling": `scribe resume`.
- "is journaling on?": `scribe status`.
- "tidy the journal", "curate the journal now": `scribe curate`. It takes a minute or two.
- "archive this project", "write it up for a stakeholder": `scribe archive`, then say where the file was saved.
- "bring in what we learned on project X": `scribe link X`. To undo: `scribe unlink X`.
- "stop the background curator": `scribe config background off`. To restart it: `scribe config background on`.
- "use a cheaper model" (or a named one): `scribe config model haiku`. Back to the usual model: `scribe config model default`.
- "turn off journaling here": confirm first, because it deletes the journal, then run `scribe off --yes`.
