# Tasks

Each checkbox is one small implementation commit. Keep `budgets.conf` unchanged. Contract checks verify instructions, not runtime model compliance; use the design's live matrix for behavioral acceptance.

## 1. Standalone research contract

- [x] 1.1 Update `global/prompts/research.md` and `global/agents/researcher.md` together: question-only standalone/web-only default, no local tools or project inference, explicit scoped read-only opt-in, no local fallback on web failure, empty-question clarification, and concise cited output without task steering. Retain existing web/local tool declarations and parallel research support. Add `scripts/test-research-contract.sh` with body/frontmatter assertions and in-memory negative fixtures for these clauses; verify it passes and that removing the default/no-local-tools/non-steering clauses makes its checks fail. Run `scripts/check.sh` to confirm both files fit their unchanged budgets.

## 2. Main-session non-steering boundary

- [ ] 2.1 Update `global/MAIN.md` so `/research` bypasses sizing/change workflows and returns an answer without applying findings or changing active-task goals; update researcher routing to web by default and explicit project lookups only. Extend the contract helper with MAIN assertions and a negative fixture removing the sizing exception; run the helper and `scripts/check.sh`, confirming MAIN remains within 30 lines / 420 words.

## 3. Preserve project planning research

- [ ] 3.1 Update the existing research steps in `global/prompts/propose.md` and `global/prompts/roadmap.md` to pass an explicit target-project root, planning goal, and relevant research questions, retaining scoped read-only lookups, outside-facts conditions, and `{previous}` spec handoffs. Extend the helper with checks for both callers and negative fixtures removing each caller's project opt-in or handoff; run the helper and `scripts/check.sh` within unchanged prompt budgets.

## 4. Integration and observable acceptance

- [ ] 4.1 Make `scripts/check.sh` invoke `scripts/test-research-contract.sh`, propagate failures, and report the offline contract result. Verify the checker works from a different working directory using its absolute path and rejects the in-memory regressions; run `scripts/check.sh` and `openspec validate standalone-research --strict` successfully. Exercise the design's live matrix in a disposable project when a Pi session with web tools is available: ponies during an active task, overlapping topic, empty question, failed web access, explicit local question, and both planning handoffs. Record observed traces or explicitly report unavailable live checks without claiming static checks prove isolation; any observed steering or unauthorized local lookup fails acceptance.
