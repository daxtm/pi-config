---
description: Implement the approved OpenSpec change (build agent), fix one round of failures, push — no PR
argument-hint: "[change-id]"
---
Apply OpenSpec change ${1:-matching the current branch (`feat/<id>`)}.

1. Confirm the change ID and branch. If switching would mix in unrelated edits, stop and report their paths.
2. Run `build` with: "Implement OpenSpec change `<id>`: every task in tasks.md." Pass the change ID as taskId and reuse it for follow-ups.
3. If it reports `scripts/check.sh` failing: run `debugger` once with the failing output. Still
   failing → stop and tell me what's wrong in plain words.
4. Reply in ≤6 lines: what now works, how to see it (command + expected output), and the observed result of `pi-test-branch status`. End with: "Happy with it? `/ship`. Want tweaks? Just say."
Tweaks I ask for afterwards go on this same branch (build or debugger, then push).
