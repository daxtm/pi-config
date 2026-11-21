## ADDED Requirements

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
