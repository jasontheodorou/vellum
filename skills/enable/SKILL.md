---
name: enable
description: Add this folder to your Vellum projects and turn on its journal.
disable-model-invocation: true
---

Run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" adopt --session ${CLAUDE_SESSION_ID}` from the project root. It adds the folder to the project list and starts a journal, or uses the one already there. Tell the person what it printed, in plain English.

Then run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" open "NAME"`, with the project name adopt printed, and follow the journal instructions it prints for the rest of this session. Never copy passwords, API keys, tokens or personal data into the journal.
