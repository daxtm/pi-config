# ADR-0002: Workflow in scripts, not prompts

- Status: Accepted
- Date: 2026-11-21
- Related: supersedes the whole v1 pi-workflow-kit

## Context
v1 put the git and shipping process into prompts and an LLM verifier. Every rule cost tokens on every
request and was interpreted differently each run. pi-config was developed with itself and deployed
from `test`, so half-built changes to `/ship` were live while being rebuilt. `ship.md` grew to 692
lines (~60% of all prompt text); rehearsal rituals burned a weekly plan quota; five changes shipped,
none of them features.

## Options
1. Keep v1 and prune it — good: no migration / bad: the loop that grew it is still there.
2. Rebuild: process in scripts and CI, models only write specs, code and fixes — good: deterministic,
   near-zero overhead tokens / bad: one-time rewrite.

## Decision
Option 2. Branching, shipping, archiving, merging into `test` and deploying are bash scripts.
Verification is GitHub Actions (`scripts/check.sh` + OpenSpec checks), not a model. The deployed
pi setup follows `main` only (what the user merged). `budgets.conf` caps every prompt and CI enforces it.

## Consequences
- Good: `/ship` costs zero tokens and behaves the same every time; a broken branch can't break the
  user's pi; prompt growth fails CI instead of creeping.
- Bad: a rule that needs judgment must be phrased as a short job for an agent, or not exist.
- Follow-up: if a script grows past ~250 lines, split it before adding more.
