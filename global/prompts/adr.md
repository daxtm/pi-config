---
description: Record a decision in docs/adr now (normally the spec agent writes ADRs on its own)
argument-hint: "<decision to record>"
---
Record an ADR for: $@

On a feature branch → write it there. On `main`/`test` → `pi-branch docs/adr-<slug>` first.
Run `spec` with: "Load the `adr` skill and write an ADR for: $@. Commit and push."
Show me the ADR title and its decision in two sentences. (`/ship` puts it on main.)
