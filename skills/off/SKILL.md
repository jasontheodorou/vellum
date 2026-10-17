---
name: off
description: Turn off Scribe for this project and delete its journal.
disable-model-invocation: true
---

This deletes the project's journal in `.scribe/`, and it cannot be undone. Tell the person that, and suggest `/scribe:archive` first if they might want to keep a copy.

Only if they confirm, run `"${CLAUDE_PLUGIN_ROOT}/bin/scribe" off --yes` from the project root and tell them the result.
