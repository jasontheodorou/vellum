---
name: archive
description: Save a single summary document of this project's journal to the desktop, and add it to the library of past projects.
disable-model-invocation: true
---

First make sure today's logbook entry in `.vellum/logbook/` is up to date, so the archive includes this session.

Then run `"${CLAUDE_PLUGIN_ROOT}/bin/vellum" archive` from the project root. It can take a minute, because it asks Claude to write the summary. Tell the person where the file was saved.
