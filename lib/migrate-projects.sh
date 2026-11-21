#!/usr/bin/env bash
# Upgrade tracked templates without switching anyone's working branch.
set -euo pipefail
kit="$(cd "$(dirname "$0")/.." && pwd)"
export PI_TEST_BRANCH=1
one() (
	set -e
	local repo="$1" branch=chore/pi-v3-project base wt
	cd "$repo"
	[[ "$(git config --local --get pi.kit || true)" == true && "$repo" != "$HOME/workspace/projects/pi-config" ]] || exit 0
	base=main
	local online=true
	if [[ "$(git config --get pi.github || true)" == false ]] || ! git remote get-url origin >/dev/null 2>&1; then online=false
	else git fetch -q --prune origin; base=origin/main; fi
	wt="$(mktemp -d)"
	trap 'git -C "$repo" -c core.hooksPath=/dev/null worktree remove -f "$wt" >/dev/null 2>&1 || rmdir "$wt" 2>/dev/null || true' EXIT
	git -c core.hooksPath=/dev/null worktree add -q --detach "$wt" "$base"
	cd "$wt"
	python3 "$kit/lib/project-v3.py" "$(basename "$repo")"
	if git diff --quiet; then exit 0; fi
	git add -u
	git commit -qm 'chore: migrate kit project templates to v3'
	if git show-ref --verify --quiet "refs/heads/$branch"; then
		git diff --quiet "$branch" HEAD || { echo "Inspect existing $branch in $repo"; exit 1; }
	else git branch "$branch" HEAD; fi
	if "$online"; then
		"$kit/bin/pi-ship" "$branch"
		"$kit/bin/pi-gh-setup" "$wt"
	else echo "Local migration prepared on $branch in $repo"; fi
)
failed=0
while IFS= read -r -d '' repo; do
	[[ -e "$repo/.git" ]] || continue
	set +e
	one "$repo"
	rc=$?
	set -e
	if (( rc )); then echo "Project migration pending: $repo" >&2; failed=1; fi
done < <(python3 - <<'PY'
import json,os
from pathlib import Path
h=Path.home()
trust=h/'.pi/agent/trust.json'
projects=set((h/'workspace/projects').glob('*'))
if trust.exists():
    projects.update(Path(p) for p,v in json.loads(trust.read_text()).items() if v is True)
for p in sorted(projects): os.write(1,os.fsencode(p)+b'\0')
PY
)
exit "$failed"
