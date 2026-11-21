# {{PROJECT_NAME}}

<!-- Project facts for pi. Sent with every request: keep it short (CI caps the kit's own prompts;
     keep this one under ~30 lines too). Ask pi: "fill in the placeholders in AGENTS.md". -->

## What this is
<one or two sentences: what it does and who uses it>

## Stack
<language/runtime + version, framework, package manager, database>

## Checks
`scripts/check.sh` runs everything (install deps, tests, lint, build). CI runs the same script.
Run / demo: `<command that shows it working>`

## Layout
<the 3-6 directories that matter and what lives in each>

## Rules
- Specs: `openspec/`. Decisions: `docs/adr/`. Plan: `docs/ROADMAP.md`.
- <project-specific rules: files not to touch, naming, error handling>
