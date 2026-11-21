# pi-config

The user's Pi coding-agent setup, managed as a project. Merged changes reach the user's pi
automatically: `pikit` deploys `main` into ~/.local/share/pi-config, whose `install.sh` writes ~/.pi/agent.

## Stack
Bash (install.sh, new-project.sh, bin/*), TypeScript Pi extensions (global/extensions), Markdown
prompts/agents/skills (global/), project templates (templates/project), OpenSpec + ADRs.

## Checks
`scripts/check.sh` — shell syntax + shellcheck, extension syntax, prompt budgets (budgets.conf).
Run / demo: `./install.sh --dry-run` (preview a deploy), `bin/pikit status`.

## Layout
- `bin/` — pikit, pi-ship, pi-branch, pi-gh-setup, pi-test-branch, pi-resolve, pi-kit-secret
- `global/` → ~/.pi/agent (AGENTS.md every agent, MAIN.md main session only, agents/, prompts/, skills/, extensions/)
- `templates/project/` — what pinew puts in each project

## Rules (read ADR-0002 before changing the workflow)
- Workflow logic goes in scripts, never in prompts. A prompt says what job to do, not how to police it.
- budgets.conf is a hard limit. Don't raise it to fit a rule — move the rule into a script.
- Extensions must never throw at load (try/catch): a broken extension can stop pi from starting.
- Scripts use absolute paths; anything that deletes files needs --dry-run. Never commit secrets.
