# Tasks

## 1. Script skeleton and refusal paths

- [x] 1.1 Create `bin/pi-takeover [repo-dir]` (bash, `set -euo pipefail`, same conventions as
      `bin/pi-gh-setup`): resolve repo dir, validate git repo + resolvable HEAD commit, `gh` auth,
      and a GitHub repo for `origin`; exit nonzero with a diagnostic on any invalid prerequisite.
      Check `git ls-remote origin refs/heads/main refs/heads/test` live; refuse (nonzero, name the
      conflicting branch, no GitHub setup) if either ref exists or the lookup itself fails.
      Commit: `feat: pi-takeover validation and refusal`.

## 2. Bootstrap and handoff

- [x] 2.1 For the Milestone 1 both-absent case only, capture HEAD before any network step, then
      push `"$head":refs/heads/main` and `"$head":refs/heads/test` to origin with explicit
      `--force-with-lease=refs/heads/main:` and `--force-with-lease=refs/heads/test:` (empty expected
      values: creation only, no existing-ref updates, no local branches, checkout untouched).
      Do not add optional-test or partial-bootstrap paths. On success invoke the sibling `pi-gh-setup` (resolved from
      the script's own real path) on the same directory, passing its output and exit status
      through, including the private-repo warning. Print the baseline SHA, the two created
      branches, the setup outcome, and `pi-branch chore/repo-baseline` as the next command;
      never create or switch to that branch. Commit: `feat: pi-takeover bootstrap and handoff`.

## 3. Installation

- [x] 3.1 Add `pi-takeover` to `install.sh`: the `link_cmd` loop and the PATH-commands comment
      header. `./install.sh --dry-run` previews the new link without creating it.
      Commit: `feat: install pi-takeover command link`.

## 4. Checks

- [x] 4.1 Add `scripts/test-pi-takeover.sh`: temp-dir fixtures — a work repo, a bare `origin`, a
      stub `gh` on PATH. Assert each refusal (existing remote branch, gh failure, not a repo)
      exits nonzero without mutation, and the happy path lands both remote refs at the captured
      SHA with the checkout unchanged. No network, no real credentials.
      Commit: `test: pi-takeover behavior, credential-free`.
- [ ] 4.2 Wire it into `scripts/check.sh` (skip gracefully when git is missing), run
      `scripts/check.sh` and `./install.sh --dry-run`, confirm both pass end to end.
      Commit: `test: check.sh runs takeover tests`.
