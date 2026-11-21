---
description: Implement the approved OpenSpec change (build agent), fix one round of failures, push — no PR
argument-hint: "[change-id]"
---
Apply OpenSpec change ${1:-matching the current branch (`feat/<id>`)}.

1. Be on its branch: `git switch feat/<id>` if you aren't. Uncommitted edits → commit them first.
2. Run `build` with: "Implement OpenSpec change `<id>`: every task in tasks.md."
3. If it reports `scripts/check.sh` failing: run `debugger` once with the failing output. Still
   failing → stop and tell me what's wrong in plain words.
4. Reply in ≤6 lines: what now works, how to see it (command + expected output), that it's in
   `test` / the live copy within a minute, and: "Happy with it? `/ship`. Want tweaks? Just say."
Tweaks I ask for afterwards go on this same branch (build or debugger, then push).
