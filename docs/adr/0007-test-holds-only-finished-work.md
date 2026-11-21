# ADR-0007: `test` holds only finished work

- Status: Accepted
- Date: 2026-11-21

## Context
`test` merged every feature branch on every commit, so half-built features (tasks still open) showed
up in `test` and in the live copy mid-development. GitHub's feature branch could also lag behind
`test`, because pushing the branch was left to the model.

## Options
1. Merge every branch on every commit (v1) — good: everything visible at once / bad: broken,
   half-done work in the place meant for trying finished features.
2. Merge a branch only when it's finished — good: `test` is "what's ready to try" / bad: you can't
   preview a feature mid-build there (check out its branch instead).

## Decision
Option 2. A `feat/` branch joins `test` once every task in its OpenSpec change is ticked; `fix/`,
`chore/` and `docs/` branches without a change join with their first commit (one-step work).
Unfinished branches are listed as waiting. Every sync also pushes local feature branches that are
ahead of GitHub (never recreating one you deleted), so GitHub matches your machine.

## Consequences
- Good: the live copy only ever runs finished features; GitHub's feature branches are never stale.
- Bad: a branch already merged into `test` under v1 rules stays there until `/test-branch rebuild`.
