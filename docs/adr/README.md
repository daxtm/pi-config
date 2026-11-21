# Decision log (ADRs)

One decision per file, `NNNN-kebab-title.md`, from [0000-template.md](0000-template.md). Written by pi
when a decision outlives one change (a dependency, a data format, an architecture choice); routine
choices stay in the OpenSpec change's `design.md`. Merging the PR accepts it. Never edited afterwards,
except to mark it superseded by a newer ADR.

| ADR | Title | Status | Date |
|---|---|---|---|
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted | 2026-11-21 |
| [0002](0002-workflow-in-scripts-not-prompts.md) | Workflow in scripts, not prompts | Accepted | 2026-11-21 |
| [0003](0003-public-repos-by-default.md) | Public repos by default | Accepted | 2026-11-21 |
| [0004](0004-script-owned-repository-takeover.md) | Script-owned repository takeover | Superseded by 0006 | 2026-11-21 |
| [0005](0005-explicit-research-scope.md) | Explicit research scope | Accepted | 2026-11-21 |
| [0006](0006-takeover-is-part-of-pinew.md) | Taking over a repo is part of `pinew` | Accepted | 2026-11-21 |
| [0007](0007-test-holds-only-finished-work.md) | `test` holds only finished work | Accepted | 2026-11-21 |

V3 supersedes the required Actions check in 0003 and extends the preview eligibility rules in 0007. See the current workflow in the root README.
