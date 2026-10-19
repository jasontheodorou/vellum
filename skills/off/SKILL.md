---
name: off
description: Turn off Vellum for this project and delete its journal.
disable-model-invocation: true
---

This deletes the project's journal folder (`.vellum/`, or `design-journal/` in projects from the earlier project kit), and it cannot be undone. Tell the person that, and suggest `/vellum:archive` first if they might want to keep a copy. If the journal is `design-journal/`, also tell them it is committed to git, so deleting it shows up as a change to commit.

Only if they confirm, run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" off --yes` from the project root and tell them the result.
