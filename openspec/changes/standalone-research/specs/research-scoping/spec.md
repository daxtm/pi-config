## Purpose

Keep research answers independent of ongoing project work unless the request explicitly asks for project-specific investigation.

## ADDED Requirements

### Requirement: Standalone research uses only the supplied question

`/research` SHALL treat its arguments as an independent informational question by default. Delegated questions, web queries, and answers SHALL NOT incorporate the working directory, repository contents, prior conversation, or active task as subject context unless the question explicitly requests that scope. The caller and researcher SHALL NOT invoke local tools for standalone research.

#### Scenario: Unrelated research during project work

- **WHEN** a snake game task is in progress and the user submits `/research ponies`
- **THEN** the delegated task contains the ponies question without snake-game context
- **AND** web queries and the cited answer concern ponies, with no game recommendations or references to the local project
- **AND** neither caller nor researcher calls `read`, `grep`, `find`, `ls`, or `bash` for this request

#### Scenario: Topic overlaps the current codebase

- **WHEN** the user submits `/research collision detection` while working on a snake game without asking about that game
- **THEN** research answers the general question without consulting or tailoring to the game implementation

#### Scenario: No usable web sources

- **WHEN** a standalone question needs sources but web tools are unavailable or fail
- **THEN** the response states the limitation without substituting local files, version commands, or project context as evidence

#### Scenario: Missing research question

- **WHEN** the user submits `/research` without a question
- **THEN** the response asks what to research without inferring the topic from the current task or reading local files

### Requirement: Project research requires explicit scope

Researcher SHALL default to web-only unless its task explicitly requests investigation of a named repository, path, or project feature, or uses wording such as “in this project.” Local lookups SHALL be read-only and limited to that requested scope. A generic feature name, library name, or incidental repository mention SHALL NOT grant access to the current codebase.

#### Scenario: Explicit current-project question

- **WHEN** the user submits `/research in this project, how does rendering work?`
- **THEN** the researcher may inspect relevant rendering code read-only and returns an explanation citing local paths and line ranges
- **AND** no unrelated files are inspected and no project files or plans are changed

#### Scenario: Explicit path or repository question

- **WHEN** the question asks how a feature works in an explicitly identified local path or repository
- **THEN** local investigation is limited to that target and the response identifies the evidence used

#### Scenario: Public repository is the named subject

- **WHEN** the user asks `/research how does github.com/acme/pony-engine implement rendering?` without requesting local investigation
- **THEN** research targets the named public repository, not the unrelated repository containing the current session

#### Scenario: Library name is not project consent

- **WHEN** the user asks `/research latest pygame release` in a repository that uses pygame
- **THEN** research checks public release information without reading dependency files or running local version commands

### Requirement: Research does not steer ongoing work

`/research` SHALL return a concise answer with sources and stop. It SHALL NOT initiate sizing, branching, planning, implementation, or task-state updates, nor turn findings into instructions for the ongoing task. Explicit project scope authorizes investigation only, not applying findings. Existing work SHALL retain its original goal and scope; scheduling is unchanged.

#### Scenario: Answer during an active build

- **WHEN** `/research ponies` is answered while a build task is active
- **THEN** the reply contains only the research answer and sources, without a Tiny/Normal/Too-big routing line or a proposal/apply handoff
- **AND** no task is cancelled, rewritten, or given pony-related follow-up work because of this request
- **AND** the active build continues under its original instructions

#### Scenario: Project findings are not applied automatically

- **WHEN** `/research in this project, compare our renderer with library X` identifies a possible improvement
- **THEN** the response explains the findings without editing code, creating a change, updating a roadmap, or assigning implementation work

### Requirement: Project planning preserves explicit research scope

`/propose` and `/roadmap` SHALL remain project-bound. When delegating research, they SHALL explicitly identify the target project and question, allowing read-only lookups relevant to the plan and preserving the cited-brief handoff. Direct researcher calls without such scope SHALL remain standalone.

#### Scenario: Propose needs codebase and external evidence

- **WHEN** `/propose` researches a change requiring outside facts and existing project behavior
- **THEN** its researcher task explicitly names the project and relevant research question
- **AND** the brief can cite relevant local code alongside public sources and is passed to the spec agent

#### Scenario: Roadmap needs codebase and external evidence

- **WHEN** `/roadmap` researches an idea requiring outside facts and existing project constraints
- **THEN** its researcher task explicitly names the project and relevant research question
- **AND** scoped read-only lookups remain available and the brief is passed to the spec agent

#### Scenario: Generic lookup routed from the main session

- **WHEN** main routes a plain lookup to `researcher` without explicit project scope
- **THEN** the researcher performs standalone research rather than inferring that the working directory is the subject
