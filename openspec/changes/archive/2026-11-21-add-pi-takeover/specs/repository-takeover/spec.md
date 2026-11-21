## Purpose

Provide a script-owned, one-time bootstrap for existing GitHub repositories without remote main or test branches while preserving the normal agent workflow restrictions.

## ADDED Requirements

### Requirement: Validate the takeover target before mutation

`pi-takeover [repo-dir]` SHALL default to the current directory and validate the git repository, a resolvable HEAD commit, GitHub authentication, and the GitHub repository associated with its `origin` remote before creating branches or changing GitHub settings. Invalid prerequisites SHALL produce a diagnostic and a nonzero exit.

#### Scenario: Explicit repository directory

- **WHEN** `pi-takeover /absolute/repo/path` is run from another directory with valid prerequisites
- **THEN** takeover operates on the supplied repository rather than the caller's repository

#### Scenario: Default directory

- **WHEN** `pi-takeover` is run without a directory in a valid repository
- **THEN** takeover targets that repository

#### Scenario: Invalid prerequisites

- **WHEN** the target is not a git repository, HEAD has no commit, gh is unavailable or unauthenticated, or no GitHub repository can be resolved for origin
- **THEN** the command exits nonzero with a diagnostic and performs no branch creation or GitHub settings mutation

### Requirement: Refuse any existing bootstrap branch

The command SHALL inspect live remote `refs/heads/main` and `refs/heads/test`, not rely on local branches or cached remote-tracking refs. If either exists, it SHALL exit nonzero, identify the conflict, leave all remote branches unchanged, and not run GitHub setup. A failed remote lookup SHALL NOT count as proof that branches are absent. Milestone 1 SHALL support only the both-absent case, not an optional-test mode or creation of just the missing branch.

#### Scenario: Only main exists remotely

- **WHEN** remote main exists and remote test is absent
- **THEN** takeover refuses without creating test, updating main, or applying GitHub settings

#### Scenario: Only test exists remotely

- **WHEN** remote test exists and remote main is absent
- **THEN** takeover refuses without creating main, updating test, or applying GitHub settings

#### Scenario: Both branches exist remotely

- **WHEN** both remote branches exist, including after a successful takeover
- **THEN** takeover refuses without changing either branch or applying GitHub settings

#### Scenario: Remote branch lookup fails

- **WHEN** the live remote branch query fails
- **THEN** takeover exits nonzero without attempting branch creation or GitHub setup

### Requirement: Bootstrap both branches from current HEAD

When neither remote branch exists, the command SHALL create and push both main and test to origin at the same captured current HEAD commit without permitting forced updates or overwriting existing branches. It SHALL preserve the local checkout, uncommitted files, existing local branches, unrelated remote branches, and GitHub default branch.

#### Scenario: Successful bootstrap from a legacy branch

- **WHEN** neither remote branch exists and HEAD points to commit H on a legacy work branch
- **THEN** remote main and test both point to H
- **AND** the local checkout and files, existing branches, and GitHub default branch remain unchanged

#### Scenario: Local names do not select the baseline

- **WHEN** neither remote branch exists but local main or test points to a different commit than HEAD
- **THEN** both new remote branches point to captured HEAD, and the existing local branches remain unchanged

### Requirement: Reuse the existing GitHub setup policy

After both branches are created successfully, the command SHALL invoke the kit's `pi-gh-setup` for the same repository and preserve its output and exit outcome. It SHALL NOT duplicate its settings or ruleset policy, change repository visibility, or claim protection beyond what that command reports.

#### Scenario: Public repository setup

- **WHEN** both branches have been created and pi-gh-setup succeeds on a public repository
- **THEN** its settings and ruleset output is visible and takeover exits successfully

#### Scenario: Private repository enforcement warning

- **WHEN** pi-gh-setup reports that private-repository rulesets cannot be enforced
- **THEN** takeover preserves the warning that main is unprotected and does not claim enforced protection

#### Scenario: Setup fails after branch creation

- **WHEN** pi-gh-setup exits nonzero
- **THEN** takeover exits nonzero, leaves its failure output visible, and does not print a successful takeover completion

### Requirement: Report the work completed and the next ordinary branch

On successful completion, the command SHALL report the baseline commit, remote branch creation, GitHub setup outcome, and `pi-branch chore/repo-baseline` as the next command. It SHALL NOT create or switch to that work branch or make a project commit. Bootstrap SHALL NOT suspend or relax existing agent restrictions at any point or grant agents permission to push protected branches directly.

#### Scenario: Successful handoff output

- **WHEN** branch creation and GitHub setup finish successfully
- **THEN** output identifies the baseline, both created branches, the setup outcome, and `pi-branch chore/repo-baseline`
- **AND** chore/repo-baseline has not been created, the checkout is unchanged, and no additional commit exists

### Requirement: Install takeover as a kit command

`install.sh` SHALL expose executable `pi-takeover` through the same command-link mechanism used for pi-gh-setup, targeting the kit's `bin/pi-takeover` by absolute path and retaining existing dry-run behavior.

#### Scenario: Command installation

- **WHEN** installation runs with no conflicting non-symlink command at the destination
- **THEN** `~/.local/bin/pi-takeover` resolves to executable `bin/pi-takeover` in the installed kit

#### Scenario: Installation preview

- **WHEN** `install.sh --dry-run` previews a missing takeover command link
- **THEN** it reports the planned link without creating it
