# ADR-0006: Taking over a repo is part of `pinew`

- Status: Accepted
- Date: 2026-11-21
- Related: supersedes [ADR-0004](0004-script-owned-repository-takeover.md); ADR-0002, ADR-0003

## Context
`pinew` assumed every repo already on GitHub has a `main` branch. A repo whose only branch was
`chore/repo-baseline` broke that assumption, so setup failed; the agent improvised direct pushes,
`pr-only` blocked them, and ADR-0004 answered with a separate `pi-takeover` command plus a roadmap
for hardening it. That fixed the symptom (a missing bootstrap step) next to the component that had
the bug, and still ended by handing the owner manual steps (default branch, visibility).

## Options
1. Keep `pi-takeover` and harden it — good: exists already / bad: two setup commands with
   overlapping jobs, and the real gap in `pinew` stays.
2. Make takeover the owner's manual job — good: no code / bad: contradicts "the workflow does
   everything except merging and deleting repos".
3. Fix `pinew`: when the repo is on GitHub without `main`, create `main` from the repo's current
   default branch (creation only, never moving an existing branch), let `pi-gh-setup` make `main`
   the default branch, then continue the normal setup — good: one command for every repo state /
   bad: none beyond the fix itself.

## Decision
Option 3. `pi-takeover`, its tests, its capability spec and its roadmap are removed. `pinew` handles a
new folder, a local-only repo, an empty GitHub repo, a GitHub repo without `main`, and an already set
up repo. `pi-gh-setup` sets the default branch to `main` whenever `main` exists. Visibility stays the
owner's decision (ADR-0003): a private repo gets the warning and the exact command, never a change.

## Consequences
- Good: "take over this repo" = run `pinew` in it; nothing for the owner to finish by hand except the
  visibility choice.
- Bad: none new. Lesson recorded: a gap in an existing script is fixed in that script, not with a new one.
