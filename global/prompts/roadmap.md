---
description: Turn a whole idea (or a big feature) into docs/ROADMAP.md — ordered small changes plus the ADRs they force
argument-hint: "<the whole thing you want, in your own words>"
---
Plan this: $@

1. `pi-branch docs/roadmap` (or `docs/roadmap-<slug>` if `docs/ROADMAP.md` already exists on main —
   then extend it).
2. If the plan depends on outside facts (libraries, hosting, prior art) or existing project
   constraints, run `researcher` first with an explicit project task: target root = this repo, the
   planning goal, and the exact outside/codebase questions; read-only lookups within that root
   only. Chain it into `spec` with `{previous}`.
3. `spec` task: "Write or extend docs/ROADMAP.md for: <the idea>. No OpenSpec changes yet. Write the
   ADRs milestone 1 forces. Fill the AGENTS.md and openspec/config.yaml placeholders that are known.
   Commit `docs: roadmap` and push."
4. Show me: goal, milestones with their change lists, each ADR's decision in one line, open questions.
   End with: "`/ship` to put the plan on main, then `/propose next`." Stop there.
