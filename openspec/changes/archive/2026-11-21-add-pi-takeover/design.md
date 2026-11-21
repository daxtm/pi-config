# Design

## Context

Adoption has no bootstrap path today: `pi-gh-setup` configures settings and rulesets but does not
create `main`/`test`, and agents are blocked from pushing them (`pr-only`). ADR-0004 authorizes a
script-owned, one-time takeover.
`bin/*` scripts are plain bash with `set -euo pipefail`, validated by `scripts/check.sh`
(syntax + shellcheck over `bin/*`), and installed as symlinks by `install.sh` (`link_cmd`).
See proposal.md for motivation; specs/ for requirements.

## Goals / Non-Goals

**Goals:**

- A single self-contained `bin/pi-takeover [repo-dir]` that matches the kit's bash conventions.
- Safe by construction: refuses whenever either remote branch exists or anything is unverifiable;
  never updates existing remote branches or touches the checkout or unrelated refs.
- Milestone 1 requires both remote branches absent and creates both; "test as needed" does not add
  an optional-test mode or support for filling in one missing branch. Those paths are deferred.
  Existing agent restrictions are never suspended; only the named kit script bootstraps refs.

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
`git push --force-with-lease=refs/heads/main: --force-with-lease=refs/heads/test: origin
"$head":refs/heads/main "$head":refs/heads/test` (one shell command) uses the commit SHA captured
before any network step. Each explicit empty expected value permits creation only, never an update
to an existing ref; do not use bare `--force`, `+` refspecs, or leases inferred from tracking refs.
No local branches are created or moved, and the checkout is untouched. A plain push is insufficient:
a concurrently created branch could be fast-forwarded to HEAD, violating the no-update contract.
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

- [Check-then-push race: something creates `main` between `ls-remote` and `push`] → explicit
  creation-only leases prevent moving that ref. If the push fails, takeover reports failure and
  does not run GitHub setup. Safe retry/recovery and a broader race-test matrix remain Milestone 2.
- [`gh` stub tests could drift from real `gh` output] → the stub only needs the exact queries
  takeover makes (auth status, repo name/owner); pi-gh-setup behavior stays covered by its own
  successful real-world use, not by the stub.
- [A failed push after one ref landed leaves a half-bootstrap] → acceptable for Milestone 1:
  takeover reports exactly what completed; Milestone 2 (harden) owns recovery. The refusal rule
  makes a re-run safe: it refuses once any remote branch exists.
