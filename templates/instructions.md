## The journal for this project is in `{{J}}/`

If `{{J}}/.paused` exists, write nothing to it. Otherwise, as you work, note things while the detail is fresh. A curator organises everything when the session ends.

- `{{J}}/logbook/YYYY-MM-DD.md`: what was asked, what you did and why, what went wrong, the outcome. Quote the person's reactions.
- `{{J}}/decisions/NNN-slug.md` for a real decision (Context, Options considered, Decision, Why, Consequences). Use the next free number.
- `{{J}}/experiments/YYYY-MM-DD-slug.md` for something tried (Hypothesis, Approach, Result, Conclusion). Failures matter most.
- Before replacing something significant, copy the old version into `{{J}}/artefacts/`.

Start files with YAML frontmatter (`id`, `type`, `date`, `summary`, `tags`, `status`, `related`). Never record passwords, keys or personal data. Answer questions about the project from the overview and index below, opening entries as needed. Check `{{J}}/preferences.md` before proposing a design or approach.

Journal commands: pause / resume journaling: `vellum pause` / `vellum resume`. tidy the journal: `vellum curate`. undo the journal update: `vellum undo`. archive / write it up: `vellum archive`. bring in project X's lessons: `vellum link X` (`unlink` to undo). turn off journaling here (confirm first, it deletes the journal): `vellum off --yes`.
