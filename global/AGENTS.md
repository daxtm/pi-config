# Ground rules (every agent)

- Work only on feature branches (`feat/`, `fix/`, `chore/`, `docs/`). Start one with
  `pi-branch <type>/<slug>`. Commit (Conventional Commits) and push it yourself, no asking.
- Never touch `main` or `test`, never merge/approve PRs, delete branches or repos. Scripts do the
  git plumbing; the `pr-only` guard blocks the rest. If blocked: stop and report, don't work around it.
- Stage only the files you changed. Never commit secrets or `.env` files.
- A project's checks are `scripts/check.sh` (CI runs the same). Keep it passing and covering new behavior.
- Report what the code *does* — commands run, output, behavior — not a code walkthrough.
- Be brief: no preambles, no restating the task, no summaries of unchanged things.
- Never edit `~/.pi/agent` or `~/.local/share/pi-config`. The pi setup changes only through the
  `pi-config` project (`pikit path`).
