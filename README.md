# pi-config

My Pi coding-agent setup: spec-driven development (OpenSpec), a decision log (ADRs), and a git
workflow that does everything except merging PRs and deleting repos. Models write specs, code and
fixes; **scripts and GitHub Actions run the process** (see [ADR-0002](docs/adr/0002-workflow-in-scripts-not-prompts.md)).

## The cycle

| You type | What happens | Done by | Model calls |
|---|---|---|---|
| `/propose <idea>` | branch `feat/<id>`, OpenSpec change (+ ADR if a real decision), pushed | spec | 1 |
| *read it, say go* | | | |
| `/apply` | a test of what you asked for written first, then the tasks until it passes; now finished, so it joins `test` / the live copy | build (+1 debugger round if red) | 1–2 |
| *try it; ask for tweaks* | same branch | build / debugger | per tweak |
| `/ship` | main merged in, tasks checked, change archived, pushed, PR opened | script | 0 |
| *CI green → you merge on GitHub* | you choose "Delete branch" or keep it | you | 0 |
| `/cleanup` | deletes local branches that no longer exist on GitHub (`--dry-run` lists them) | script | 0 |

Also: `/fix <symptom>` (or `/fix ci` when the PR's CI is red), `/roadmap <big idea>` then
`/propose next`, `/research <question>` (standalone answer by default; project look-ups only when
the question names this project, a repo, or a path — see
[ADR-0005](docs/adr/0005-explicit-research-scope.md)), `/adr <decision>`, `/commit`. Tiny edits: just ask — the
main session does them on a `chore/` branch, then `/ship` (in pi-config itself every change goes
through `/propose`, so it's designed and tested, never patched in mid-task).

Scripts (no model): `/ship`, `/cleanup [--dry-run]`, `/switch [branch]`, `/test-branch [rebuild]`, `/live …`, `/pinew <name>`,
`/zsh on|off`, `/web on|off`.

## Branches
- `feat/` `fix/` `chore/` `docs/` — where all work happens; pi commits and pushes them.
- `test` — `main` plus every **finished** branch, pushed to GitHub: a `feat/` branch joins once every
  task in its OpenSpec change is ticked (`/apply` done); `fix/` `chore/` `docs/` branches join with their
  first commit. Unfinished work stays out (`/test-branch` lists what's waiting). A live copy (e.g. a
  ComfyUI node) follows it. Conflicts are resolved by the model, never by you. Nothing ships from `test`.
  Feature branches are pushed to GitHub automatically after every commit.
- `main` — changes only when you merge a PR. Merge with **Create a merge commit**.

## New projects: `pinew <name>`
Creates `~/workspace/projects/<name>` with git, OpenSpec, AGENTS.md, ADRs, `scripts/check.sh`,
CI (`.github/workflows/ci.yml`, job `check`), a **public** GitHub repo named like the folder, merge-commit-only settings (branches are never auto-deleted), and rulesets on main
(PR + green `check` required, no force-push/deletion) and test (no deletion).
Repos are public because **GitHub Free enforces rulesets on public repos only** — that's what makes
"PR + green CI before merge" a hard rule instead of a habit. Never commit secrets (anyone can read the
repo). `--private` exists, but then main is unprotected and pi-gh-setup warns about it. Run `pinew` inside an existing project to set it up or take it over, whatever state it's in (no
`main` yet, a different default branch, or already set up): the changes arrive as a PR.

## Changing this setup
This repo is a normal project: `/propose`, `/apply`, `/ship`, merge. `pikit` deploys what's on
**main** into `~/.local/share/pi-config` → `~/.pi/agent` (pi checks at startup; or run `pikit apply`).
Try a branch first: `pikit use feat/x` · back: `pikit use main` · state: `pikit status`.
Prompts are capped by `budgets.conf` — CI fails if one grows past it.

Models per role: `agent-models.conf`. Logins: `/login` in pi. Web keys: `~/.config/pi-kit/secrets.env`.

Break-glass if pi won't start:
`git -C ~/.local/share/pi-config checkout --detach origin/main && ~/.local/share/pi-config/install.sh`
