---
name: pause
description: Pause Vellum for this project, so nothing is written to the journal until it is resumed.
disable-model-invocation: true
---

Run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" pause` from the project root. For the rest of this session, write nothing to the journal folder (`.vellum/`, or `design-journal/` in projects from the earlier project kit) unless the person resumes journaling. Nothing from a paused session is kept for recall, and the curator does not run on it.

Then tell them: "Journaling is paused. Run /vellum:resume, or say 'resume journaling', to turn it back on."
