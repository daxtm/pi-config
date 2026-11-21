# ADR-0005: Explicit research scope

- Status: Accepted
- Date: 2026-11-21
- Related: standalone-research; ADR-0002

## Context

Research is used both for independent questions and for project planning. The shared researcher currently permits local tools without an explicit scope boundary. Main-session routing sizes every request, while `/research` only delegates a question and summarizes the result. Prompt budgets are hard limits, and workflow enforcement belongs in scripts.

## Options

1. Keep one researcher with an explicit standalone default and project opt-in — minimal deployment change and preserved planning lookups / behavioral restrictions depend on instruction following.
2. Add a web-only agent and a separate project researcher — tool lists separate capabilities / duplicates instructions and routing, and alone does not prevent main-session steering or inherited project context.
3. Introduce a separate command/process with sanitized context and restricted tools — stronger mechanical isolation / adds lifecycle, configuration, and result-delivery machinery beyond the requested prompt contract.

## Decision

Choose option 1: research is informational and web-only by default; only an explicit question about a repository, path, or project feature authorizes scoped read-only local investigation. Main delegates a self-contained question and returns the answer without applying it to ongoing work. `/propose` and `/roadmap` explicitly identify project scope when invoking the same researcher.

This is a shared behavioral contract, not a sandbox or a claim that the main conversation loses access to its history. Retain the researcher's local tools for project-scoped planning. Use offline contract checks plus observed tool traces to verify the boundary; do not describe static text checks as runtime enforcement. Keep the rules concise under existing budgets, consistent with ADR-0002's allowance for judgment-based agent jobs.

## Consequences

- Good: Independent questions no longer imply project investigation or changes, while planning keeps one cited-brief interface and the existing model configuration.
- Bad: Local tools remain technically available, and Pi may load project instructions at startup; prompts must not use that ambient material as research subject context. There is no mechanical isolation guarantee.
- Cost: Every project-bound research caller must supply explicit scope. A live trace that reads local files or steers work fails acceptance even if the static checks pass; hard isolation would require a separately designed tooling change rather than a claim this contract provides it.
