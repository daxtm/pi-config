# Design

## Context

See `proposal.md` for motivation and `specs/research-scoping/spec.md` for the behavior contract.

- `global/prompts/research.md` currently delegates `$@`, permits up to three parallel researchers, and returns a short answer. It has no scope or non-steering instructions.
- `global/agents/researcher.md` exposes local read/search/bash tools alongside web MCP tools. Its Codebase guidance applies unconditionally.
- `global/MAIN.md` sizes every request and routes generic lookups to researcher. Research must be exempt from change-sizing, not accidentally classified as a new feature.
- `/propose` and `/roadmap` chain research into spec using `{previous}` when outside facts are needed. These callers are intentionally project-bound.
- `install.sh` fetches Pi's example subagent implementation and deploys agent templates with model substitution. The inspected implementation starts a fresh JSON/print process with `--no-session`, but retains the working directory and appends the agent prompt. A separate conversation does not mean project instructions cannot be loaded.
- `scripts/check.sh` currently checks syntax and budgets, not research contracts. Current limits are 30 lines / 320 words per prompt, 45 / 480 per agent, and 30 / 420 for MAIN.

## Goals / Non-Goals

**Goals:** Make the scoping and output rules agree across the entry prompt, shared researcher, and main routing; preserve explicitly requested read-only project research and planning handoffs.

**Non-Goals:** A second agent, process isolation, queue changes, removing conversation history, or enforcement against an adversarial model. Do not modify the installed Pi example or add an extension.

## Decisions

### 1. Prompt-level scoping, not a tooling split

See ADR-0005 (`docs/adr/0005-explicit-research-scope.md`). Retain the existing agent and tool list, with a strong default contract: no `read`/`grep`/`find`/`ls`/`bash` calls unless the task explicitly requests project investigation. No version checks, discovery calls, or local fallback when web access fails. Ambient project metadata and instructions are not evidence or subject context for standalone questions; ordinary safety and read-only restrictions still apply.

A web-only second agent would block its local tools but would not by itself stop main-session task steering. Full isolation would require new command/process machinery. The request permits a prompt contract, and the existing fresh subagent context plus a question-only handoff avoids deliberately injecting active-task context without changing the runtime.

### 2. Scope comes from the request, not the directory

Use two clear terms throughout: **standalone** (default, web-only) and **project-scoped** (explicit, read-only). Examples:

| Question | Scope |
|---|---|
| `ponies`, `collision detection`, `latest pygame release` | Standalone, even if related to current work |
| `in this project, how does rendering work?` | Current project, rendering only |
| `how does /absolute/repo/src/render.ts work?` | Explicit local path |
| `how does the renderer in repo /absolute/repo work?` | Explicit repository and feature |
| `how does github.com/acme/pony-engine implement rendering?` | Named public repo; no access to the current local repo |

Merely mentioning a feature/library is not consent to inspect a matching local implementation. If the requested local target is genuinely ambiguous, ask for clarification rather than searching unrelated directories. Empty arguments ask for a question rather than deriving one from ongoing work.

### 3. Bound both delegation and the caller's response

`research.md` passes only the supplied question plus the scope/output contract. Do not append a project summary, active task, prior findings, or instructions to apply the result. For explicit “this project” questions only, include the known target root needed to resolve that request. Independent parts can still use up to three researchers, each receiving only its own question and explicitly allowed scope.

The prompt and MAIN agree that `/research` is an answer-only exception to the size-first rule: no Tiny/Normal/Too-big line, branching, propose/apply handoff, plan updates, or edits. Return a few sentences and sources, then stop. This remains true for project-scoped questions. A running task is not cancelled, rewritten, or assigned new work from the findings; do not merge the answer into its instructions. Existing scheduling is unchanged, and this is not a claim that results disappear from main-session history.

### 4. Preserve planning with explicit caller scope

Change the researcher description and MAIN row to “web by default; explicit project lookups.” MAIN's generic lookup delegation follows the same rule. In both `propose.md` and `roadmap.md`, the existing research step must construct a task identifying the target project root, the planning goal, and the relevant codebase/external questions. Use the known project context rather than extra discovery solely to construct the task. Keep read-only scope, `{previous}`, research conditions, and the existing spec handoff unchanged. A project-planning prompt is itself an explicit project request; the shared researcher must not have to infer that from a later chain step.

### 5. Test contracts honestly within fixed budgets

Add `scripts/test-research-contract.sh` using Bash and absolute paths derived from its own location. Keep it offline and invoke it from `scripts/check.sh`. Check the relevant Markdown bodies/frontmatter, not just descriptions:

- research prompt: supplied-argument delegation, standalone default, explicit opt-in, no task steering, concise cited answer, empty-question handling;
- researcher: explicit web-only default, enumerated local-tool restriction and scoped read-only exception, no local fallback, and retained web/local tool declarations;
- MAIN: answer-only exception to sizing and conditional project lookup routing;
- both planning prompts: explicit target-project research instruction and preserved `{previous}` handoff.

Assertions must fail if a required contract is removed from an in-memory copy of an input, especially the non-steering clause or project-planning opt-in. Use in-memory negative fixtures rather than modifying source files or creating cleanup/deletion machinery. Keep the helper callable from any working directory. These are text-contract regression checks, not proof of LLM behavior. Existing budget enforcement remains authoritative: trim descriptions/output boilerplate to fit, never raise `budgets.conf` or move long instructions into always-loaded text. No new workflow logic belongs in these prompts.

## Risks / Trade-offs

- **Model ignores a behavioral boundary** → Inspect live delegation, tool, and answer traces; any local lookup or task redirection on standalone research fails acceptance. Do not weaken the spec to make a transcript pass.
- **Ambient project instructions are loaded by Pi** → Explicitly prohibit using them to shape the research subject. This change cannot promise zero automatic filesystem access or an empty project context at process startup.
- **Project research silently becomes web-only** → Both planning callers supply explicit scope; verify each with a codebase-plus-external question.
- **Static checks overstate confidence** → Label them contract checks and supplement them with the manual matrix below. No claim of runtime tool blocking.
- **Budget creep** → Enforce existing limits with `scripts/check.sh`; localize the short rules rather than duplicating a long policy in every prompt.

## Verification and Migration

Run `scripts/check.sh` and `openspec validate standalone-research --strict`. After normal deployment and `/reload`, use a disposable snake-game project and inspect traces:

1. With unrelated work active, `/research ponies`: only the question is delegated; no local tools, game references, state updates, implementation handoff, or task redirection. Existing work retains its goal.
2. `/research collision detection`: still standalone despite topic overlap. `/research` asks for a topic. Failed web research reports the limitation without local fallback.
3. `/research in this project, how does rendering work?`: relevant read-only lookups and path/line citations; no edits or newly assigned work.
4. Exercise `/propose` and `/roadmap` with a question needing public facts and local constraints; inspect explicit project-scoped tasks and cited brief handoffs. Inspect in a controlled/disposable project because these commands normally create planning branches/artifacts.

Record observed traces or report any unavailable live validation; static passing checks alone do not establish non-steering behavior. Deployment uses the existing install flow, with no settings/model migration. Roll back by reverting the implementing commit and redeploying through the normal workflow.

## Open Questions

None. The accepted scope is behavioral isolation; hard process isolation is explicitly excluded rather than left undecided.
