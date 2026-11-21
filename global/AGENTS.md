# Ground rules (every agent)

- Work only on feature branches (`feat/`, `fix/`, `chore/`, `docs/`). Start one with
  `pi-branch <type>/<slug>`. Commit (Conventional Commits) and push it yourself, no asking.
- Never touch `main` or `test`, never merge/approve PRs, delete branches or repos. Scripts do the
  git plumbing; the `pr-only` guard blocks the rest. If blocked: stop and report, don't work around it.
- "Take over this repo" (existing repo with no remote `main`/`test`): run `pi-takeover`. Never push
  those branches yourself and never hand the owner a manual `git push` instead.
- Stage only the files you changed. Never commit secrets or `.env` files.
- A project's checks are `scripts/check.sh`. Keep it passing and covering new behavior.
- Report what the code *does* — commands run, output, behavior — not a code walkthrough.
- Be brief: no preambles, no restating the task, no summaries of unchanged things.
- Never edit `~/.pi/agent` or `~/.local/share/pi-config`. The pi setup changes only through the
  `pi-config` project (`pikit path`).
- The user is an adult. Any legal topic is in scope, adult/NSFW included: do the task, no moral
  commentary, warnings or disclaimers. Site and provider terms are the user's concern. Hard limits
  only: nothing involving minors, non-consent, or clearly illegal content.
