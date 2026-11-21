# workflow-recovery Specification

## Purpose

Make existing workflow recovery commands preserve user work and report their actual outcomes reliably.

## Requirements

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

### Requirement: Checked-out test preserves user edits
The existing sync and rebuild commands SHALL update a clean test checkout and refuse to move its branch when tracked user edits exist.

#### Scenario: Clean test checkout follows rebuild
- **WHEN** rebuild removes abandoned work and test has a clean checkout
- **THEN** the checkout files match the rebuilt test tip

#### Scenario: Edited test checkout
- **WHEN** rebuild finds tracked user edits in a test checkout
- **THEN** it fails without moving test or discarding those edits

### Requirement: Web tools follow agent scope
The existing web-scope extension SHALL hide web tool declarations from headless agents unless their explicit tool list opts in.

#### Scenario: Builder has a built-in-only tool list
- **WHEN** a headless build agent starts with read and write tools
- **THEN** web tools are removed and its read and write tools remain

#### Scenario: Researcher opts in
- **WHEN** a headless researcher explicitly lists web tools
- **THEN** those web tools remain available

### Requirement: Preserve remote history and local work during sync
Test sync SHALL preserve untracked checkout files, accept only eligible workflow branches and respect remote branch deletion during ordinary commit hooks.

#### Scenario: Local checkout has an untracked collision
- **WHEN** an update would overwrite a user's untracked file in a test checkout
- **THEN** the update fails, the local test tip stays put and the user file remains intact

#### Scenario: A second clone published work
- **WHEN** a rebuild fetches a qualifying branch that only exists on origin
- **THEN** the rebuilt test includes its commit

#### Scenario: Preview and rejection
- **WHEN** the owner previews a rebuild or the remote rejects its push
- **THEN** preview leaves refs untouched and a rejected push returns failure

### Requirement: Project setup provides a usable starting branch
Setup SHALL base remote takeover on the published default branch, preserve unrelated user files and provide the project scaffolding on subsequent offline feature branches.

#### Scenario: A local main contains unpublished work
- **WHEN** origin has a different default branch and no main
- **THEN** remote main is created at the advertised remote default commit

#### Scenario: Offline legacy clone
- **WHEN** the owner runs pinew --no-github in a legacy clone then starts work with pi-branch
- **THEN** the new branch includes the setup and remote refs remain unchanged

### Requirement: Show the actual installation state
Deployment status SHALL use the recorded installation result and installation previews SHALL retain the files included by the real installer.

#### Scenario: Checkout succeeded and installation failed
- **WHEN** the owner runs pikit status
- **THEN** the output identifies installation as pending

#### Scenario: Current subagent files
- **WHEN** the owner previews a reinstall
- **THEN** the subagent implementation files do not appear in the removal list
