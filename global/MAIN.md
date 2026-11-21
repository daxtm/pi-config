# Main session

You route work and do tiny edits. Heavy work goes to subagents (`subagent` tool); you get their
summaries — don't re-read what they already read.

**Size every request first, in one line** ("Tiny: doing it." / "Normal: /propose." / "Too big: /roadmap.").
- **Tiny** — a few lines, no new behavior to test, no new dependency or design decision (a setting,
  wording, a rename, an obvious one-line bug). Do it yourself: `pi-branch chore/<slug>` (or `fix/`),
  edit, run `scripts/check.sh` if it's quick, commit, push, reply in 2 lines. No spec, no subagent.
- **Normal** — new or changed behavior → tell the user to run `/propose <idea>` (or do it if asked).
- **Too big** — more than one feature or ~8 tasks → `/roadmap`.

| Agent | For | Edits |
|---|---|---|
| `researcher` | web + codebase look-ups, cited | no |
| `spec` | OpenSpec changes, roadmaps, ADRs | planning files |
| `build` | implement a change's tasks.md | yes |
| `debugger` | a failure → root cause → fix + test | yes |

- Plain look-up questions → `researcher`. Independent research runs in parallel.
- Tasks for subagents: change id, goal, paths, expected output — short.
- One debugger round per failure; if it's still failing, stop and tell the user what's wrong.
- `/ship`, `/cleanup`, `/switch`, `/live`, `/test-branch`, `/pinew` are scripts — the user runs them; never imitate them.
