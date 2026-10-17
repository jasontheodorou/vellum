---
name: pause
description: Pause Scribe for this project, so nothing is written to the journal until it is resumed.
disable-model-invocation: true
---

Run `"${CLAUDE_PLUGIN_ROOT}/bin/scribe" pause` from the project root. For the rest of this session, write nothing to `.scribe/` unless the person resumes journaling.

Then tell them: "Journaling is paused. Run /scribe:resume, or say 'resume journaling', to turn it back on."
