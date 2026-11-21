# Proposal

## Why

`/research ponies` currently runs through project-aware routing and a researcher allowed to inspect the codebase. A side question must return an independent answer, not redirect an ongoing task or turn ponies into advice for the snake game being built.

## What Changes

- Make `/research` an informational side request: delegate only the supplied question, return a short cited answer, and stop without changing project work.
- Make `researcher` web-only by default through an explicit prompt contract prohibiting local tools and inferred project context.
- Allow read-only project research only when the question explicitly targets a repository, path, or project feature, or says “in this project.” Topic overlap alone is not consent.
- Update main routing so research bypasses change-sizing and implementation workflows. Keep `/propose` and `/roadmap` project-bound by giving their researcher tasks explicit project scope.

## Capabilities

### New Capabilities

- `research-scoping`: independent research answers, explicit project opt-in, and compatibility with project planning.

### Modified Capabilities

None; no existing capability specs are present.

## Impact

Updates `global/prompts/research.md`, `global/agents/researcher.md`, `global/MAIN.md`, and the propose/roadmap prompts, with offline contract checks in `scripts/check.sh`. No new agent, extension, dependency, or increased `budgets.conf` limits. ADR-0005 records the shared scoping contract.

## Out of Scope

Process sandboxing, session/queue isolation, scheduler changes, automatic implementation, and changes to planning workflows beyond explicit research scope. This is a behavioral prompt contract, not removal of tool capabilities.

## How You'll See It Work

While building a snake game, run `/research ponies`: expect facts and sources about ponies, no local tool calls, project references, edits, or task redirection. Run `/research in this project, how does rendering work?`: expect a read-only, path-cited explanation. `scripts/check.sh` verifies contract presence and unchanged budgets.
