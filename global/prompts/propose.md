---
description: Write an OpenSpec change for an idea (or the next roadmap item) on its own branch, then stop for your review
argument-hint: "<idea | next>"
---
Propose: $@

1. If it says `next`: take the first unchecked `- [ ]` item in `docs/ROADMAP.md` (use its change id).
   If it's tiny (see your sizing rules), say so and do it directly instead.
2. Pick a short kebab-case change id. Run `pi-branch feat/<id>`.
3. If it depends on outside facts (APIs, libraries, versions) or existing project behavior, run
   `researcher` first with an explicit project task: target root = this repo, the planning goal,
   and the exact outside/codebase questions; read-only lookups within that root only. Chain it
   into `spec` with `{previous}`. Otherwise run `spec` alone. Task:
   "Write OpenSpec change `<id>` for: <the request, in the user's words>."
4. Relay the spec agent's summary (≤8 lines). End with: "Review it, then `/apply` — or tell me what
   to change." Stop there.
