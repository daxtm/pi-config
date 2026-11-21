#!/usr/bin/env bash
# pinew — set up a project for the pi workflow (new or existing, including OpenCode projects).
#
#   git + OpenSpec + project AGENTS.md + ADRs + PR template + CI (GitHub Actions running
#   scripts/check.sh and the OpenSpec checks) + pi trust + hooks that keep `test` up to date
#   + a PUBLIC GitHub repo named exactly like the folder (public, so GitHub Free enforces the branch
#   rulesets), with merge settings and rulesets. Never commit secrets: anyone can read a public repo.
# Nothing that already exists is overwritten; existing specs and changes are kept.
#
# Usage:  pinew <name>            create and set up ~/workspace/projects/<name>
#         pinew /abs/dir          set up that folder
#         pinew                   set up the current folder
# Options:
#   --private                     make the GitHub repo private instead. GitHub Free does NOT enforce
#                                 branch rulesets on private repos — main would be unprotected.
#   --no-github                   no GitHub repo
#   --live <path> [--live-branch <b>]   keep <path> as a live copy following <b> (default test)
#   (ComfyUI nodes get their live copy in <ComfyUI>/custom_nodes/<name> automatically.)
#
# Where the setup files land: a brand-new or never-pushed repo → committed on main. A repo already on
# GitHub → committed on a chore/pi-setup-<date> branch, pushed, and shipped as a PR for you to merge.
# Taking over a GitHub repo that has no `main` yet: `main` is created from the repo's current default
# branch (or your local main / current commit) — creation only, an existing branch is never moved —
# and pi-gh-setup makes it the default branch. Then the normal setup above continues.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
TEMPLATE="$KIT_DIR/templates/project"
AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
PROJECTS_ROOT="$HOME/workspace/projects"
TODAY="$(date +%Y-%m-%d)"

TARGET=""; LIVE_PATH=""; LIVE_BRANCH="test"; GITHUB=1; VISIBILITY="--public"
while [ $# -gt 0 ]; do
	case "$1" in
	--live) LIVE_PATH="${2:?--live needs a path}"; shift ;;
	--live-branch) LIVE_BRANCH="${2:?--live-branch needs a branch}"; shift ;;
	--no-github) GITHUB=0 ;;
	--private) VISIBILITY="--private" ;;
	--public) VISIBILITY="--public" ;;
	-h|--help) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
	-*) echo "unknown option: $1" >&2; exit 2 ;;
	*) TARGET="$1" ;;
	esac
	shift
done

# 0. Folder
if [ -n "$TARGET" ]; then
	case "$TARGET" in /*) PROJECT_DIR="$TARGET" ;; *) PROJECT_DIR="$PROJECTS_ROOT/$TARGET" ;; esac
	if [ -d "$PROJECT_DIR" ]; then echo "project    $PROJECT_DIR already exists"; else mkdir -p "$PROJECT_DIR"; echo "project    created $PROJECT_DIR"; fi
	cd "$PROJECT_DIR"
fi
PROJECT_DIR="$(pwd -P)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# 1. Git, and where the setup files go
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { git init -q -b main; echo "git        initialised (branch main)"; }
HAS_HEAD=0; git rev-parse -q --verify HEAD >/dev/null && HAS_HEAD=1
HAS_ORIGIN=0; git remote get-url origin >/dev/null 2>&1 && HAS_ORIGIN=1
SETUP_BRANCH=""; RETURN_TO=""
# Existing projects always receive setup on a work branch. Local-only setup disables the
# automatic remote sync too, so --no-github cannot push through the test-branch hook.
if (( GITHUB )); then git config --local --unset pi.github 2>/dev/null || true
else git config --local pi.github false; fi
mapfile -d '' -t USER_UNTRACKED < <(git ls-files --others --exclude-standard -z)
if (( HAS_HEAD )); then
	[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "ERROR: commit or stash your changes first (git status)" >&2; exit 1; }
	if (( HAS_ORIGIN && GITHUB )); then
		git fetch -q --prune origin
		if ! git rev-parse -q --verify refs/remotes/origin/main >/dev/null; then
			src=""; from=""
			if git rev-parse -q --verify refs/heads/main >/dev/null; then src="$(git rev-parse refs/heads/main)"; from="your local main"
			else
				def="$(git ls-remote --symref origin HEAD 2>/dev/null | sed -n 's|^ref: refs/heads/\([^[:space:]]*\)[[:space:]]*HEAD$|\1|p')"
				if [ -n "$def" ] && git rev-parse -q --verify "refs/remotes/origin/$def" >/dev/null; then
					src="$(git rev-parse "refs/remotes/origin/$def")"; from="GitHub's default branch $def"
				else src="$(git rev-parse HEAD)"; from="the current commit"; fi
			fi
			git push -q --force-with-lease=refs/heads/main: origin "$src:refs/heads/main" \
				|| { echo "ERROR: couldn't create main on GitHub (nothing else was changed)" >&2; exit 1; }
			git fetch -q origin
			echo "github     the repo had no main — created it from $from (${src:0:7})"
		fi
	fi
	RETURN_TO="$(git branch --show-current)"
	SETUP_BRANCH="chore/pi-setup-$(date +%Y%m%d-%H%M%S)-$$"
	base=HEAD
	if (( GITHUB && HAS_ORIGIN )); then base=origin/main
	elif git rev-parse -q --verify refs/heads/main >/dev/null; then base=main; fi
	git switch -q --no-track -c "$SETUP_BRANCH" "$base"
	echo "git        setup goes on $SETUP_BRANCH (from $base)"
fi

# 2. OpenSpec (the kit's pinned CLI)
OPENSPEC_BIN=""
# shellcheck disable=SC1091
[ -f "$KIT_DIR/.kit-paths" ] && . "$KIT_DIR/.kit-paths"
[ -n "$OPENSPEC_BIN" ] && [ -x "$OPENSPEC_BIN" ] || OPENSPEC_BIN="$(command -v openspec || true)"
[ -n "$OPENSPEC_BIN" ] || { echo "ERROR: openspec not found — run: pikit apply" >&2; exit 1; }
HAD_CONFIG=0; [ -e openspec/config.yaml ] && HAD_CONFIG=1
out="$(OPENSPEC_TELEMETRY=0 "$OPENSPEC_BIN" init --tools pi --scope project --no-animation . 2>&1)" \
	|| { echo "$out" >&2; echo "ERROR: openspec init failed" >&2; exit 1; }
if (( HAD_CONFIG )); then echo "openspec   kept existing openspec/config.yaml"
else cp "$TEMPLATE/openspec/config.yaml" openspec/config.yaml; echo "openspec   ready (lean rules in openspec/config.yaml)"; fi

# 3. Project files (each only if missing)
place() { # template-relative path [mode]
	[ -e "$1" ] && return 0
	mkdir -p "$(dirname "$1")"
	sed -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" -e "s|{{DATE}}|$TODAY|g" "$TEMPLATE/$1" > "$1"
	if [ -n "${2:-}" ]; then chmod "$2" "$1"; fi
	echo "created    $1"
}
place AGENTS.md
if grep -qiE 'opencode|/verify|verifier' AGENTS.md; then
	echo "AGENTS.md  mentions OpenCode or the old verifier — ask pi to \"update AGENTS.md to the template in $TEMPLATE/AGENTS.md, keep the project facts\""
fi
place scripts/check.sh 755
place .github/workflows/ci.yml
place .github/pull_request_template.md
place docs/adr/README.md
place docs/adr/0000-template.md
place docs/adr/0001-record-architecture-decisions.md
if ! { [ -f .gitignore ] && grep -q "pi-workflow-kit" .gitignore; }; then
	{ [ -s .gitignore ] && echo; cat "$TEMPLATE/gitignore.append"; } >> .gitignore
	echo "created    .gitignore entries"
fi

# 4. Trust the project in pi (subagents can't answer the trust prompt)
mkdir -p "$AGENT_DIR"
node - "$AGENT_DIR/trust.json" "$PROJECT_DIR" <<'NODE'
const fs = require("fs");
const [file, dir] = process.argv.slice(2);
let data = {};
if (fs.existsSync(file)) data = JSON.parse(fs.readFileSync(file, "utf8").replace(/^﻿/, ""));
data[dir] = true;
fs.writeFileSync(file, JSON.stringify(Object.fromEntries(Object.keys(data).sort().map((k) => [k, data[k]])), null, 2) + "\n");
NODE
echo "pi         trusted $PROJECT_DIR"

# 5. Hooks: every commit keeps `test` up to date
git config --local pi.kit true
HOOKS_DIR="$(git rev-parse --path-format=absolute --git-path hooks)"
mkdir -p "$HOOKS_DIR"
TB="$HOME/.local/bin/pi-test-branch"
HOOK_LINE="[ -n \"\$PI_TEST_BRANCH\" ] || [ ! -x \"$TB\" ] || ( \"$TB\" --quiet >/dev/null 2>&1 & ) # pi-workflow-kit"
for hook in post-commit post-merge post-rewrite; do
	f="$HOOKS_DIR/$hook"
	[ -f "$f" ] || printf '#!/bin/sh\n' > "$f"
	sed -i '/# pi-workflow-kit$/d' "$f"; printf '%s\n' "$HOOK_LINE" >> "$f"; chmod +x "$f"
done
echo "git        hooks keep the test branch up to date"

# 6. Commit the setup; existing projects retain their unrelated untracked files.
if (( HAS_HEAD )); then
	git add -u
	while IFS= read -r -d '' file; do
		keep=0
		for prior in "${USER_UNTRACKED[@]}"; do [[ "$file" != "$prior" ]] || { keep=1; break; }; done
		(( keep )) || git add -- "$file"
	done < <(git ls-files --others --exclude-standard -z)
else git add -A; fi
if git diff --cached --quiet; then
	echo "git        nothing new to commit"
else
	PI_TEST_BRANCH=1 git commit -q -m "chore: set up the pi workflow (OpenSpec, ADRs, CI)"
	echo "git        committed the setup on $(git branch --show-current)"
fi

# 7. GitHub
if (( GITHUB )); then
	if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
		echo "github     gh not logged in — later: gh auth login, then run pinew here again"
	elif (( ! HAS_ORIGIN )); then
		if gh repo view "$PROJECT_NAME" >/dev/null 2>&1; then
			echo "github     a repo named $PROJECT_NAME already exists on your account — not touching it."
			echo "           if it's this project: git remote add origin \"\$(gh repo view $PROJECT_NAME --json sshUrl -q .sshUrl)\" && pinew"
		else
			gh repo create "$PROJECT_NAME" "$VISIBILITY" --source . --remote origin >/dev/null
			git push -q -u origin main
			echo "github     created ${VISIBILITY#--} repo $(gh repo view --json nameWithOwner -q .nameWithOwner) and pushed main"
			"$KIT_DIR/bin/pi-gh-setup" "$PROJECT_DIR" || true
		fi
	else
		if [ -z "$SETUP_BRANCH" ] && ! git ls-remote --exit-code -q origin main >/dev/null 2>&1; then
			git push -q -u origin main   # an empty GitHub repo: main goes up first
			echo "github     pushed main"
		fi
		"$KIT_DIR/bin/pi-gh-setup" "$PROJECT_DIR" || true
		if [ -n "$SETUP_BRANCH" ]; then
			if git diff --quiet "${base:-main}" HEAD; then
				git switch -q "$RETURN_TO" 2>/dev/null || git switch -q --detach "${base:-main}"
				git branch -q -D "$SETUP_BRANCH"
				echo "git        already set up — nothing to ship"
			else
				git push -q -u origin "$SETUP_BRANCH"
				"$KIT_DIR/bin/pi-ship" "$SETUP_BRANCH" || echo "github     couldn't open the PR — run: pi-ship $SETUP_BRANCH"
				[ -n "$RETURN_TO" ] && git switch -q "$RETURN_TO"
			fi
		fi
	fi
fi

# 8. `test` branch now, plus the live copy
if git rev-parse -q --verify HEAD >/dev/null; then
	if [ -n "$LIVE_PATH" ]; then
		"$KIT_DIR/bin/pi-test-branch" live-set --adopt "$LIVE_PATH" "$LIVE_BRANCH" | sed 's/^/live       /'
	else
		"$KIT_DIR/bin/pi-test-branch" --adopt | sed 's/^/live       /'
	fi
	echo "test       branch ready"
fi

[ -n "${PINEW_CD_FILE:-}" ] && printf '%s' "$PROJECT_DIR" > "$PINEW_CD_FILE"
echo
echo "Next: cd $PROJECT_DIR && pi"
echo "  new project:      /roadmap <the whole idea>   or   /propose <one feature>"
echo "  existing project: ask pi to \"fill in the placeholders in AGENTS.md, openspec/config.yaml and scripts/check.sh\""
exit 0
