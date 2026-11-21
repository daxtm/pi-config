## Purpose
Make existing workflow recovery commands preserve user work and report their actual outcomes reliably.

## ADDED Requirements

### Requirement: Rebuild replaces stale test history
The existing test-branch command SHALL reset local and remote test to main plus eligible branches even when no merge is necessary.

#### Scenario: All old work was abandoned
- **WHEN** rebuild runs with only main and a stale test branch remaining
- **THEN** both local and remote test equal main

### Requirement: Deleted and unfinished branches stay excluded
The existing sync command SHALL prune deleted remote branches before auto-pushing and exclude changed active OpenSpec changes with missing or unfinished tasks.

#### Scenario: A remote branch was deleted
- **WHEN** sync fetches after a tracked branch was deleted remotely
- **THEN** it does not recreate that branch

#### Scenario: Tasks are missing
- **WHEN** a branch adds an active change without tasks.md
- **THEN** it is listed as waiting and excluded from test

### Requirement: Existing project setup preserves work
The existing pinew command SHALL keep --no-github setup local and stage only files created by its setup process in existing repositories.

#### Scenario: Local setup with an existing origin
- **WHEN** pinew --no-github runs in a repository with an origin
- **THEN** no remote branch or GitHub setting changes and setup stays on a local work branch

#### Scenario: Unrelated untracked file
- **WHEN** pinew sets up an existing repository containing an unrelated untracked file
- **THEN** that file remains untracked and is absent from setup commits

### Requirement: Deployment success controls skipping
The existing pikit command SHALL skip unchanged installation only after successful installation of that commit.

#### Scenario: Installation failed after checkout
- **WHEN** apply --if-changed runs again after an installation failure
- **THEN** it retries installation at the same commit
