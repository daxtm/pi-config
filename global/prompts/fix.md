---
description: Fix a bug or a red CI run (debugger agent) on the current branch or a new fix/ branch, push — no PR
argument-hint: "<symptom | ci>"
---
Fix: $@

1. On a feature branch → fix it there. On `main`/`test` → `pi-branch fix/<short-slug>`.
2. If it says `ci` (or CI failed on the PR): the task is "CI failed on this branch — read the log
   (`gh run view --log-failed`) and fix it". Otherwise the task is the symptom as I described it.
3. Run `debugger` with that task.
4. Reply in ≤5 lines: root cause, fix, check result, and: "`/ship` when you're happy" (on a fix/
   branch), or "pushed — the PR updates itself" (if this branch already has a PR).
