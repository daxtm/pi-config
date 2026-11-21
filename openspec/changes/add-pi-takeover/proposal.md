# Proposal

## Why

An existing GitHub repository without remote `main` and `test` has no supported bootstrap path into the kit's normal workflow. Agents must not improvise direct pushes to those branches; ADR-0002 assigns git plumbing to scripts, and ADR-0004 authorizes a narrowly scoped takeover command.

## What Changes

- Add `bin/pi-takeover [repo-dir]`, defaulting to the current directory, for Milestone 1 of the adoption roadmap.
- Validate the repository, GitHub remote, authentication, and current HEAD; inspect live remote branches before making changes.
- Refuse if either remote `main` or `test` exists. Otherwise create both from the same current HEAD without overwriting or force-pushing.
- Reuse `pi-gh-setup` for settings and rulesets, preserving its private-repository warning.
- Install the command through the existing `install.sh` command-link mechanism and add credential-free checks.
- Report the baseline, created branches, setup outcome, and `pi-branch chore/repo-baseline` as the next step; do not start that branch.

## Capabilities

### New Capabilities

- `repository-takeover`: One-time bootstrap of an existing GitHub repository into the ordinary branch workflow.

### Modified Capabilities

None; this branch has no existing capability specs.

## Impact

Touches `bin/pi-takeover`, `install.sh`, and shell checks/tests. No new dependencies or prompt-budget changes. Backed by [ADR-0004](../../../docs/adr/0004-script-owned-repository-takeover.md), read from `docs/roadmap`, and ADR-0002; no new ADR is needed.

## Out of Scope

Retries, partial-failure recovery, baseline selection options, default-branch switching, README/agent-handoff documentation, `pr-only` changes, and a smoke harness belong outside this milestone.

## How You'll See It Work

On a disposable GitHub repository with neither remote branch, run `pi-takeover /absolute/repo/path`. Expect both branches at the reported HEAD, existing GitHub setup output, and the next-work-branch command. Repeating it refuses without changing branches.
