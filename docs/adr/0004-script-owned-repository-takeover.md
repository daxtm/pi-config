# ADR-0004: Script-owned repository takeover

- Status: Superseded by [ADR-0006](0006-takeover-is-part-of-pinew.md)
- Date: 2026-11-21
- Related: add-pi-takeover (planned); docs/ROADMAP.md; follows ADR-0002

## Context
An existing git repository can have a GitHub remote but neither remote `main` nor `test`.
In a smoke test, an agent improvised a baseline workflow and direct pushes; `pr-only` correctly
blocked them. Normal feature-branch work needs a baseline, but agents must not gain permission to
push protected branches. ADR-0002 already places git plumbing in scripts rather than prompts.

## Options
1. Require the owner to create both branches manually — good: no bootstrap command / bad: a manual
   prerequisite remains, and agents still lack a supported takeover handoff.
2. Add a narrowly scoped kit script for initial branch creation — good: repeatable bootstrap with
   unchanged agent restrictions / bad: partial failures and existing branches need careful handling.
3. Allow agents to push protected branches during takeover — good: no new script / bad: weakens the
   guard and makes the bootstrap boundary depend on model judgment.

## Decision
Option 2. Provide `pi-takeover [repo-dir]` for repositories with a GitHub remote. It validates the
repository and GitHub authentication, creates missing remote `main` and `test` from one baseline
(current HEAD by default, or an explicitly selected commit), then reuses `pi-gh-setup` for settings
and rulesets. It never updates, force-pushes, deletes, or renames an existing remote branch.

This is one-time branch creation by a kit script, not an exception for agent-issued git commands.
After bootstrap, normal workflow rules remain unchanged; `pr-only` gains no exceptions. The script
prints the ordinary work branch to start next, such as `chore/repo-baseline`; actual project changes
belong in that branch's PR. Existing ruleset policy remains authoritative: `main` requires a PR and
green CI, `test` prevents deletion, and private-repository enforcement limits remain explicit.

## Consequences
- Good: adoption has a named, repeatable entry point without weakening the agent's safety boundary.
- Bad: branch creation and GitHub settings are not atomic; protection can fail after branches exist.
  Output and retries must expose partial completion without moving existing branches or claiming
  unavailable protection. A baseline can publish existing history, so the owner must trust it.
- Follow-up: define safe handling of partially initialized repositories and explicit baseline
  selection before implementing those paths; default-branch migration is not decided here.
