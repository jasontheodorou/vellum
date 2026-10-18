---
name: pause
description: Pause Vellum for this project, so nothing is written to the journal until it is resumed.
disable-model-invocation: true
---

Run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" pause` from the project root. For the rest of this session, write nothing to `.vellum/` unless the person resumes journaling.

Then tell them: "Journaling is paused. Run /vellum:resume, or say 'resume journaling', to turn it back on."
