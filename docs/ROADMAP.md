# Roadmap: adopt an existing repository

## Goal
Provide `pi-takeover [repo-dir]` for an existing git repository with a GitHub remote but no remote
`main` or `test`. The script establishes both branches from current HEAD (or an explicitly chosen
baseline commit), applies the existing GitHub setup, and prints the work branch to start next
(e.g. `chore/repo-baseline`). The first real change goes through a normal feature-branch PR.

The smoke test exposed a missing bootstrap path, not a broken guard: the agent improvised direct
pushes and `pr-only` correctly blocked them. Agents must invoke `pi-takeover` by name instead.

## Decisions and boundaries
- [ADR-0004](adr/0004-script-owned-repository-takeover.md): only the kit script creates missing
  bootstrap branches, once; it never overwrites existing branches. Normal ground rules then apply.
- [ADR-0002](adr/0002-workflow-in-scripts-not-prompts.md) already assigns git plumbing to scripts;
  no second ADR is needed for that principle or for reusing `pi-gh-setup`.
- Reuse `pi-gh-setup` validation and ruleset policy, including its private-repository warning;
  do not promise enforced protection where GitHub cannot provide it. Scripts use absolute paths.
- Out of scope: `pr-only` exceptions, history rewriting, deleting/renaming branches, changing
  visibility, creating GitHub repositories, automatic merges, or project scaffolding in the baseline.
- Root `AGENTS.md` and `openspec/config.yaml` have no unfilled placeholders; leave them unchanged.
  Template placeholders are intentional, not missing pi-config facts.

## Milestone 1 — walking skeleton
- [ ] add-pi-takeover — Ship an installed command that validates repo/GitHub/auth, creates absent remote `main` and `test` from HEAD, reuses `pi-gh-setup`, and prints the next work branch; cover the happy path and existing-branch refusal in `scripts/check.sh`.

This milestone implements ADR-0004. Success is observable end to end: on a disposable GitHub repo
without either branch, `pi-takeover /absolute/repo/path` reports the baseline, branch creation,
GitHub setup outcome, and `pi-branch chore/repo-baseline` as the next step. It does not claim to have
started that branch or made the first project change.

## Milestone 2 — safe retries and baseline selection
- [ ] harden-pi-takeover — Add explicit baseline selection and safe rerun/partial-failure handling without updating existing branches; test invalid inputs, auth/remote failures, branch races, and ruleset failures through `scripts/check.sh`.

Rerunning never moves an existing remote branch. Failures identify what completed and what needs
attention; a ruleset failure must not look like a fully protected takeover. Keep the existing
`bin/*` coverage for `bash -n` and shellcheck, and run behavioral tests without live credentials.

## Milestone 3 — agent handoff and smoke proof
- [ ] document-pi-takeover-handoff — Update README and takeover/smoke instructions to invoke `pi-takeover` by name, add a short template AGENTS.md pointer only if needed, and verify the first ordinary branch PR plus unchanged guard behavior in `scripts/check.sh`.

Prompts state the job, never reproduce bootstrap commands or policing logic; stay within budgets.
The smoke test should show the agent invoking the script, then starting the printed branch, while
direct agent pushes to `main`/`master`/`test` remain blocked. Each checklist item is one future
`/propose` → `/apply` cycle; this roadmap creates no OpenSpec changes.

## Open questions
- What baseline option spelling and confirmation should be required when selecting a commit other
  than HEAD, or when the working tree contains uncommitted changes?
- If only one remote branch exists (including after interruption), when may takeover safely create
  the other, and how should it verify the original baseline without changing the existing branch?
- Should takeover change GitHub's default branch from a legacy branch to `main`, or leave that as an
  explicit owner action? Preserve the legacy branch either way.
- Where should the reproducible smoke scenario live? There is no checked-in smoke harness today.
