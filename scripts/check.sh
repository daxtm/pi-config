#!/usr/bin/env bash
# pi-config's checks — run by the build agent and by GitHub Actions on every PR.
#   1. every shell script parses (and passes shellcheck, when it's installed — CI has it)
#   2. every TypeScript extension parses (esbuild)
#   3. prompts/agents/skills stay inside budgets.conf
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
cd "$ROOT"
fail=0
bad() { echo "FAIL $*"; fail=1; }

mapfile -t scripts < <(printf '%s\n' install.sh new-project.sh bin/* scripts/*.sh templates/project/scripts/check.sh | sort -u)
before=$fail
for f in "${scripts[@]}"; do bash -n "$f" || bad "bash syntax: $f"; done
if command -v shellcheck >/dev/null; then
	shellcheck -S warning -e SC2016 "${scripts[@]}" || bad "shellcheck"
else
	echo "skip shellcheck (not installed)"
fi
(( fail == before )) && echo "ok   ${#scripts[@]} shell scripts"

# bin/pi-takeover behavior: temp-dir fixtures with a stub gh — no network, no real credentials
if command -v git >/dev/null; then
	bash scripts/test-pi-takeover.sh || bad "pi-takeover behavior"
else
	echo "skip pi-takeover tests (no git)"
fi

if command -v npx >/dev/null; then
	n=0; before=$fail
	for f in global/extensions/*.ts; do
		npx -y esbuild@0.28.2 "$f" --log-level=error >/dev/null || bad "TypeScript syntax: $f"
		n=$((n + 1))
	done
	(( fail == before )) && echo "ok   $n extensions parse"
else
	echo "skip extension syntax (no npx)"
fi

shopt -s nullglob
before=$fail
while read -r glob lines words; do
	[[ -z "$glob" || "$glob" == \#* ]] && continue
	for f in $glob; do
		l="$(wc -l < "$f")"; w="$(wc -w < "$f")"
		if (( l > lines || w > words )); then bad "budget: $f is $l lines / $w words (max $lines / $words) — move rules into a script"; fi
	done
done < budgets.conf
(( fail == before )) && echo "ok   budgets"

before=$fail
bash "$ROOT/scripts/test-research-contract.sh" || bad "research contract checks (see FAIL lines above)"
(( fail == before )) && echo "ok   research contract checks"

if [[ -n "${GITHUB_BASE_REF:-}" ]] && git diff --name-only "origin/$GITHUB_BASE_REF...HEAD" 2>/dev/null | grep -qx budgets.conf; then
	echo "::warning file=budgets.conf::This PR changes the prompt budgets — make sure that's on purpose"
fi

exit "$fail"
