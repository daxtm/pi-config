# Design

## Context

Adoption has no bootstrap path today: `pi-gh-setup` assumes `main`/`test` exist, and agents are
blocked from pushing them (`pr-only`). ADR-0004 authorizes a script-owned, one-time takeover.
`bin/*` scripts are plain bash with `set -euo pipefail`, validated by `scripts/check.sh`
(syntax + shellcheck over `bin/*`), and installed as symlinks by `install.sh` (`link_cmd`).
See proposal.md for motivation; specs/ for requirements.

## Goals / Non-Goals

**Goals:**

- A single self-contained `bin/pi-takeover [repo-dir]` that matches the kit's bash conventions.
- Safe by construction: refuses whenever either remote branch exists or anything is unverifiable;
  never force-pushes, never touches the checkout or unrelated refs.

**Non-Goals (design-level):**

- No flags beyond `[repo-dir]` — baseline selection, retries, partial-failure recovery are
  Milestone 2; handoff docs are Milestone 3.
- No GitHub API work beyond what `pi-gh-setup` already does — takeover calls it, it doesn't
  re-implement it.

## Decisions

**One new script, not an extension of `pi-gh-setup`.** The two have opposite failure contracts:
`pi-gh-setup` is idempotent and safe to re-run; takeover is one-time and must *refuse* on re-run.
Merging them would make "safe to re-run any time" false for the combined command.
Alternative: a `--bootstrap` flag on `pi-gh-setup` — rejected, the refusal logic would still need
its own path and the flag would suggest bootstrap is a routine operation.

**Live remote check via `git ls-remote origin`, then push by captured HEAD SHA.**
`git ls-remote origin refs/heads/main refs/heads/test` is queried live (never cached
remote-tracking refs); an empty answer plus exit 0 means absent. Branches are created with
`git push origin "$head":refs/heads/main "$head":refs/heads/test` from the commit SHA captured
before any network step — no local branches are created or moved, the checkout is untouched, and
a plain push (no `--force`) fails safely if anything appears at the ref between check and push.
Alternative: create local branches then push them — rejected: collides with existing local
branches and pollutes refs the spec promises not to touch.

**Reuse `pi-gh-setup` by invoking it on the same directory.** Takeover resolves the sibling script
relative to its own real path (works both in the repo and deployed via symlink) and passes through
its output and exit status verbatim, including the private-repo ruleset warning. Alternative:
factor shared code into a sourced helper — rejected; the kit's scripts stay standalone and the
ruleset policy stays authoritative in one place.

**Credential-free behavioral tests, driven from `scripts/check.sh`.** A new
`scripts/test-pi-takeover.sh` builds throwaway fixtures in a temp dir: a work repo with commits,
a bare repo as its `origin`, and a stub `gh` prepended to PATH that fakes auth/repo resolution.
It exercises the refusal paths (existing branch, gh failure) and the happy path (assert both
remote refs point at the captured SHA, checkout unchanged). `check.sh` runs it only when git is
available; it never touches the network or real credentials. Syntax + shellcheck coverage is
automatic via the existing `bin/*` glob.

## Risks / Trade-offs

- [Check-then-push race: something creates `main` between `ls-remote` and `push`] → plain push of
  a new ref fails non-zero without overwriting anything; takeover reports the failure and does
  not run GitHub setup.
- [`gh` stub tests could drift from real `gh` output] → the stub only needs the exact queries
  takeover makes (auth status, repo name/owner); pi-gh-setup behavior stays covered by its own
  successful real-world use, not by the stub.
- [A failed push after one ref landed leaves a half-bootstrap] → acceptable for Milestone 1:
  takeover reports exactly what completed; Milestone 2 (harden) owns recovery. The refusal rule
  makes a re-run safe: it refuses once any remote branch exists.
