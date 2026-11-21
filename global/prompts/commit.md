---
description: Commit the current changes (Conventional Commits, grouped) and push — no PR
argument-hint: "[hint about the change]"
---
Commit the current changes without asking me. ${@:-}
- On `main`/`test` → `pi-branch <feat|fix|chore|docs>/<slug>` first (your edits come along).
- `git status` + `git diff`; group into logical commits; stage explicit paths only.
- Skip anything that looks like secrets, local env or build output, and tell me.
- Push. Show the new commits (`git log --oneline`).
