---
name: off
description: Turn off Vellum for this project and delete its journal.
disable-model-invocation: true
---

This deletes the project's journal in `.vellum/`, and it cannot be undone. Tell the person that, and suggest `/vellum:archive` first if they might want to keep a copy.

Only if they confirm, run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" off --yes` from the project root and tell them the result.
