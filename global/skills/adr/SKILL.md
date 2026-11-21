---
name: adr
description: Write or supersede a decision record in docs/adr/. Use whenever a decision outlives one change — a new dependency, framework, storage, data format, API/CLI contract, deployment target, or cross-cutting pattern.
---

# Decision records (ADRs)

Write one, without asking, in the same branch as the work, when a decision outlives this change:
- a new runtime dependency, framework, language, database or external service
- a data model, file format or public API/CLI others will rely on
- auth/security model, deployment target, infrastructure layout
- a cross-cutting pattern (errors, logging, config, testing), or deliberately rejecting the obvious option
Routine implementation choices go in the OpenSpec change's `design.md`, not here.
Check `docs/adr/README.md` first: if an ADR already covers it, follow it.

## Create
1. Next number: highest `docs/adr/NNNN-*.md` + 1 (4 digits, never renumber).
2. Copy `docs/adr/0000-template.md` to `docs/adr/NNNN-short-kebab-title.md`, fill every section:
   status `Accepted` (merging the PR accepts it), today's date, the change id under Related, at
   least two real options, the deciding reason, honest costs. Under one page.
3. Add `| [NNNN](NNNN-title.md) | Title | Accepted | YYYY-MM-DD |` to `docs/adr/README.md`.
4. Link it from the change's `design.md` (`See ADR-NNNN`) if there is one.
5. Commit `docs(adr): NNNN <title>` on the current branch.

## Supersede
Write a new ADR (`Related: supersedes ADR-XXXX`); in the old one change only the status line to
`Superseded by ADR-NNNN`; update both index rows.
