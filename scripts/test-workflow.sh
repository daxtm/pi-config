#!/usr/bin/env bash
# Behavior tests for the workflow scripts — what the user would observe, not just that code parses.
# Runs everything in a throwaway HOME with a fake GitHub (bare git repos behind a stub `gh`) and a
# stub `pi` (the conflict resolver). No network, no credentials. Needs git, node and openspec.
#
# Covers: pinew (new public repo, --private, taking over a repo with no main, a repo that already
# has main), the `test` rules (only finished work, auto-push, never recreating deleted branches),
# /ship (refuses unchecked tasks, archives, opens the PR), /cleanup, pikit, and the pr-only guard.
#
# Usage: scripts/test-workflow.sh        (prints one line per check; exit 1 if any fails)
set -uo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
fails=0; passes=0
pass() { passes=$((passes + 1)); echo "  ok   $*"; }
fail() { fails=$((fails + 1)); echo "  FAIL $*"; }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi; }

for c in git node; do command -v "$c" >/dev/null || { echo "test-workflow: $c is required"; exit 1; }; done
if ! command -v openspec >/dev/null; then
	[[ -n "${CI:-}" ]] && { echo "test-workflow: openspec is required in CI"; exit 1; }
	echo "test-workflow: openspec is required (run pikit apply or install @fission-ai/openspec@2.1.1)" >&2; exit 1
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
H="$T/home"; GH="$T/github"; STUBS="$T/stubs"; LOG="$T/log"
mkdir -p "$H/.local/bin" "$H/workspace/projects" "$H/.pi/agent" "$GH/repos" "$GH/prs" "$STUBS" "$LOG"
printf '[user]\n\tname = Test\n\temail = test@example.com\n[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n' > "$H/.gitconfig"
echo '{}' > "$H/.pi/agent/trust.json"

# ---- fake GitHub: `gh` backed by bare repos in $GH/repos ----------------------------------------
cat > "$STUBS/gh" <<'EOF'
#!/usr/bin/env bash
S="${FAKEGH:?}"; echo "gh $*" >> "$S/calls.log"
name_of() { basename "$(git remote get-url origin 2>/dev/null)" .git; }
arg_after() { local want="$1" prev="" a; shift; for a in "$@"; do [[ "$prev" == "$want" ]] && { echo "$a"; return; }; prev="$a"; done; }
case "$1 $2" in
"auth status") exit 0 ;;
"repo view")
	n=""; [[ -n "${3:-}" && "$3" != --* ]] && n="$3"; n="${n:-$(name_of)}"; b="$S/repos/$n.git"
	[[ -n "$n" && -d "$b" ]] || { echo "Could not resolve to a Repository" >&2; exit 1; }
	case "$(arg_after -q "$@")" in
	*nameWithOwner*) echo "tester/$n" ;; *visibility*) cat "$b.vis" ;; *sshUrl*) echo "$b" ;;
	*defaultBranchRef*) git -C "$b" symbolic-ref --short HEAD 2>/dev/null ;; *) echo "{}" ;;
	esac ;;
"repo create")
	n="$3"; vis=PRIVATE; [[ " $* " == *" --public "* ]] && vis=PUBLIC
	git init -q --bare -b main "$S/repos/$n.git"; echo "$vis" > "$S/repos/$n.git.vis"
	git remote add origin "$S/repos/$n.git" ;;
"api "*|"api -X")
	b="$S/repos/$(name_of).git"; vis="$(cat "$b.vis" 2>/dev/null)"
	if [[ "$*" == *rulesets* ]]; then
		if [[ "$*" == *-X* ]]; then
			[[ "$vis" == PUBLIC ]] || { echo '{"message":"Upgrade to GitHub Pro or make this repository public to enable this feature."}' >&2; exit 1; }
			cat >/dev/null; echo "ruleset applied" >> "$S/calls.log"
		fi
		exit 0
	fi
	db="$(arg_after -f "$@")"; [[ "$db" == default_branch=* ]] && git -C "$b" symbolic-ref HEAD "refs/heads/${db#default_branch=}"
	[[ " $* " == *" --input - "* ]] && cat >/dev/null
	exit 0 ;;
"pr list") f="$S/prs/$(arg_after --head "$@" | tr / _)"; [[ -f "$f" ]] && head -n1 "$f"; exit 0 ;;
"pr create")
	head="$(arg_after --head "$@")"; n=$(( $(find "$S/prs" -type f | wc -l) + 1 ))
	{ echo "https://github.com/tester/$(name_of)/pull/$n"; cat "$(arg_after --body-file "$@")"; } > "$S/prs/${head//\//_}"
	head -n1 "$S/prs/${head//\//_}" ;;
*) echo "fake gh: unhandled: $*" >&2; exit 1 ;;
esac
EOF
# ---- stub pi: the headless conflict resolver keeps both sides ------------------------------------
cat > "$STUBS/pi" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -p ]]; then
	for f in $(git diff --name-only --diff-filter=U); do sed -i -E '/^(<{7}|={7}|>{7})( |$)/d' "$f"; git add "$f"; done
	git -c core.hooksPath=/dev/null commit -q --no-edit
fi
EOF
chmod +x "$STUBS/gh" "$STUBS/pi"
for c in pi-test-branch pi-ship pi-branch pi-gh-setup; do ln -s "$ROOT/bin/$c" "$H/.local/bin/$c"; done
ln -s "$ROOT/new-project.sh" "$H/.local/bin/pinew"

export HOME="$H" FAKEGH="$GH" PI_CODING_AGENT_DIR="$H/.pi/agent" OPENSPEC_TELEMETRY=0
export PATH="$STUBS:$H/.local/bin:$PATH" GIT_CONFIG_NOSYSTEM=1
unset GIT_DIR GIT_WORK_TREE GITHUB_ACTIONS
export PI_TEST_BRANCH=1   # each scenario syncs explicitly; hooks must not race its assertions
P="$H/workspace/projects"
remote_has() { git -C "$GH/repos/$1.git" rev-parse -q --verify "refs/heads/$2" >/dev/null; }
default_of() { git -C "$GH/repos/$1.git" symbolic-ref --short HEAD; }
sync() { pi-test-branch "$@" >/dev/null 2>&1; }   # explicit sync; waits for any hook-started one

# ---- pinew -------------------------------------------------------------------------------------
echo "pinew"
(cd "$P" && pinew demo > "$LOG/pinew-demo.txt" 2>&1); D="$P/demo"
check "new project gets a public GitHub repo" grep -qx PUBLIC "$GH/repos/demo.git.vis"
check "main ruleset applied (PR + green CI enforced)" grep -q "rulesets on: main" "$LOG/pinew-demo.txt"
check "secret push protection turned on" grep -q "push protection on" "$LOG/pinew-demo.txt"
check "GitHub never auto-deletes branches" grep -q "delete_branch_on_merge=false" "$GH/calls.log"
check "CI workflow and scripts/check.sh are in the repo" test -f "$D/.github/workflows/ci.yml" -a -x "$D/scripts/check.sh"
check "test branch exists on GitHub" remote_has demo test

(cd "$P" && pinew secret --private > "$LOG/pinew-private.txt" 2>&1)
check "--private repo warns that main is unprotected" grep -q UNPROTECTED "$LOG/pinew-private.txt"

# takeover: a repo on GitHub whose only branch is chore/repo-baseline (no main, no test)
git init -q --bare -b chore/repo-baseline "$GH/repos/legacy.git"; echo PUBLIC > "$GH/repos/legacy.git.vis"
git clone -q "$GH/repos/legacy.git" "$T/seed" 2>/dev/null
(cd "$T/seed" && echo "old work" > notes.txt && git add -A && git commit -q -m "old work" && git push -q origin chore/repo-baseline 2>/dev/null)
git clone -q "$GH/repos/legacy.git" "$P/legacy" 2>/dev/null
base_sha="$(git -C "$P/legacy" rev-parse HEAD)"
git -C "$P/legacy" switch -q -c main
git -C "$P/legacy" commit -q --allow-empty -m 'local-only work'
git -C "$P/legacy" switch -q chore/repo-baseline
(cd "$P/legacy" && pinew > "$LOG/pinew-takeover.txt" 2>&1)
check "takeover: main created on GitHub from the old default branch" test "$(git -C "$GH/repos/legacy.git" rev-parse main 2>/dev/null)" = "$base_sha"
check "takeover: old branch untouched" test "$(git -C "$GH/repos/legacy.git" rev-parse chore/repo-baseline)" = "$base_sha"
check "takeover: main is now the default branch" test "$(default_of legacy)" = main
check "takeover: test branch exists" remote_has legacy test
check "takeover: setup arrives as a PR (nothing pushed to main)" bash -c "ls '$GH/prs' | grep -q chore_pi-setup && test \"\$(git -C '$GH/repos/legacy.git' rev-parse main)\" = '$base_sha'"
check "takeover: rulesets applied" grep -q "rulesets on: main" "$LOG/pinew-takeover.txt"

# a repo that already has main: just the setup PR
(cd "$P/demo" && pinew > "$LOG/pinew-again.txt" 2>&1)
check "re-running pinew on a set-up repo changes nothing" grep -q "nothing to ship" "$LOG/pinew-again.txt"

# ---- test branch + ship ----------------------------------------------------------------------------
echo "test branch, ship"
cd "$D" || exit 1
pi-branch feat/add-hello >/dev/null 2>&1
mkdir -p openspec/changes/add-hello/specs/hello bin
printf '## Why\nThe demo needs a visible first feature so the owner can see the workflow end to end.\n\n## What Changes\n- Add bin/hello.\n' > openspec/changes/add-hello/proposal.md
printf '## Purpose\nPrint a friendly greeting so the owner can see the project running.\n\n## ADDED Requirements\n\n### Requirement: Greeting\nThe system SHALL print hello.\n\n#### Scenario: Run it\n- **WHEN** the user runs bin/hello\n- **THEN** it prints hello\n' > openspec/changes/add-hello/specs/hello/spec.md
printf -- '- [ ] 1.1 Add bin/hello ([x] is the done marker)\n' > openspec/changes/add-hello/tasks.md
git add -A && git commit -q -m "docs(openspec): propose add-hello"; sync
check "feature branch pushed to GitHub without anyone pushing" test "$(git rev-parse feat/add-hello)" = "$(git -C "$GH/repos/demo.git" rev-parse feat/add-hello 2>/dev/null)"
check "unfinished feature kept out of test" bash -c "! git merge-base --is-ancestor feat/add-hello test"
st="$(pi-test-branch status 2>&1)"
check "status lists it as waiting (0/1 tasks)" grep -q 'waiting.*feat/add-hello (add-hello: 0/1 tasks)' <<<"$st"
check "ship refuses unchecked tasks" bash -c "! pi-ship"
printf '#!/bin/sh\necho hello\n' > bin/hello; chmod +x bin/hello; sed -i 's/- \[ \]/- [x]/' openspec/changes/add-hello/tasks.md
git add -A && git commit -q -m "feat: hello"; sync
check "finished feature joins test" git merge-base --is-ancestor feat/add-hello test
pi-ship > "$LOG/ship.txt" 2>&1
check "ship opens the PR" grep -q "PR opened" "$LOG/ship.txt"
check "ship archived the change" test -d "$(ls -d openspec/changes/archive/*-add-hello 2>/dev/null | head -n1)"
check "PR body carries the proposal" grep -q '^### Why' "$GH/prs/feat_add-hello"
pi-branch fix/greeting >/dev/null 2>&1; echo "greeting fix" > GREETING.md; git add GREETING.md; git commit -q -m "fix: greeting"; sync
check "fix/ branch joins test right away" bash -c "test \"\$(git rev-parse fix/greeting)\" != \"\$(git rev-parse origin/main)\" && git merge-base --is-ancestor fix/greeting test"

# ---- merge on GitHub, cleanup -------------------------------------------------------------------
echo "cleanup"
gh_merge() { # repo branch [keep] — "Create a merge commit"; deletes the branch unless keep
	local c="$T/merge-$RANDOM"; git clone -q "$GH/repos/$1.git" "$c" 2>/dev/null
	git -C "$c" -c core.hooksPath=/dev/null merge -q --no-ff "origin/$2" -m "Merge pull request from $2" && git -C "$c" push -q origin main 2>/dev/null
	[[ "${3:-}" == keep ]] || git -C "$GH/repos/$1.git" branch -q -D "$2"; rm -rf "$c"
}
gh_merge demo feat/add-hello; gh_merge demo fix/greeting keep
git switch -q main; sync --fetch
check "sync never deletes branches" git rev-parse -q --verify refs/heads/feat/add-hello
check "cleanup --dry-run lists the deleted one, deletes nothing" bash -c "pi-test-branch cleanup --dry-run | grep -q 'would delete feat/add-hello' && git rev-parse -q --verify refs/heads/feat/add-hello"
git branch -q local-wip
pi-test-branch cleanup >/dev/null 2>&1
check "cleanup deletes a branch gone from GitHub" bash -c "! git rev-parse -q --verify refs/heads/feat/add-hello"
check "cleanup keeps a merged branch you kept on GitHub" git rev-parse -q --verify refs/heads/fix/greeting
check "cleanup never touches a never-pushed branch" git rev-parse -q --verify refs/heads/local-wip
git branch -q feat/gone origin/main; git push -q -u origin feat/gone 2>/dev/null; git switch -q feat/gone; echo pending > pending; git add pending; git commit -q -m pending; git switch -q main
git -C "$GH/repos/demo.git" branch -q -D feat/gone
sync
check "a branch you deleted on GitHub is never pushed back" bash -c "! git -C '$GH/repos/demo.git' rev-parse -q --verify refs/heads/feat/gone"
check "test contains everything merged to main" git merge-base --is-ancestor origin/main test

# ---- pikit -------------------------------------------------------------------------------------
echo "pikit"
K="$P/pi-config"; git init -q --bare -b main "$GH/repos/pi-config.git"
git init -q -b main "$K"; printf '#!/usr/bin/env bash\necho installed > "$HOME/installed-from"; git -C "$(dirname "$0")" rev-parse --abbrev-ref HEAD >> "$HOME/installed-from"\n' > "$K/install.sh"; chmod +x "$K/install.sh"
git -C "$K" add -A; git -C "$K" commit -q -m init; git -C "$K" remote add origin "$GH/repos/pi-config.git"; git -C "$K" push -q -u origin main 2>/dev/null
git -C "$K" worktree add -q --detach "$H/.local/share/pi-config" main
git -C "$K" switch -q -c chore/try; echo x > "$K/x"; git -C "$K" add x; git -C "$K" commit -q -m try; git -C "$K" push -q -u origin chore/try 2>/dev/null
"$ROOT/bin/pikit" use chore/try >/dev/null 2>&1
check "pikit use deploys a branch to try" test -f "$H/.local/share/pi-config/x"
gh_merge pi-config chore/try
"$ROOT/bin/pikit" apply --if-changed --quiet >/dev/null 2>&1
check "after merging, pikit goes back to following main" bash -c "'$ROOT/bin/pikit' status | grep -q 'follows main'"

# ---- recovery regressions ----------------------------------------------------------------------
echo "recovery"
cd "$D" || exit 1
pi-branch fix/missing-tasks >/dev/null 2>&1
mkdir -p openspec/changes/missing-tasks
echo '## Why' > openspec/changes/missing-tasks/proposal.md
git add openspec; git commit -q -m 'propose without tasks'; sync
check "active change without tasks stays out of test" bash -c '! git merge-base --is-ancestor fix/missing-tasks test'

# Rebuild's zero-merge path must discard an old test tip, including in its live worktree.
R="$P/rebuild"; git init -q --bare -b main "$GH/repos/rebuild.git"
git clone -q "$GH/repos/rebuild.git" "$R" 2>/dev/null
cd "$R" || exit 1
echo base > base; git add base; git commit -q -m base; git push -q -u origin main 2>/dev/null
git switch -q -c fix/abandoned; echo abandoned > abandoned; git add abandoned; git commit -q -m abandoned
sync; pi-test-branch live-set "$T/rebuild-live" >/dev/null 2>&1
git worktree add -q "$T/rebuild-test-checkout" test
git switch -q main; git branch -q -D fix/abandoned
# Remove the branch remotely, as an owner would; rebuild fetches/prunes before syncing.
git -C "$GH/repos/rebuild.git" branch -q -D fix/abandoned
old_test="$(git rev-parse test)"; echo 'user edit' > "$T/rebuild-test-checkout/base"
check "rebuild refuses a test checkout with tracked edits" bash -c '! pi-test-branch rebuild'
check "refusal preserves the test branch tip" test "$(git rev-parse test)" = "$old_test"
check "refusal preserves user edits" grep -qx 'user edit' "$T/rebuild-test-checkout/base"
git -C "$T/rebuild-test-checkout" restore base
pi-test-branch rebuild > "$LOG/rebuild.txt" 2>&1
check "rebuild with nothing eligible resets local test to main" test "$(git rev-parse test)" = "$(git rev-parse main)"
check "rebuild with nothing eligible resets remote test to main" test "$(git -C "$GH/repos/rebuild.git" rev-parse test)" = "$(git rev-parse main)"
check "rebuild updates the live worktree" test ! -e "$T/rebuild-live/abandoned"
check "rebuild updates a clean checkout of test" test ! -e "$T/rebuild-test-checkout/abandoned"

# --no-github must not create remote main, call gh or push any branch.
git init -q --bare -b legacy "$GH/repos/offline.git"; echo PUBLIC > "$GH/repos/offline.git.vis"
git clone -q "$GH/repos/offline.git" "$P/offline" 2>/dev/null
cd "$P/offline" || exit 1
echo base > base; git add base; git commit -q -m base; git push -q -u origin legacy 2>/dev/null
before_refs="$(git -C "$GH/repos/offline.git" show-ref)"; before_calls="$(wc -l < "$GH/calls.log")"
echo 'user work' > unrelated.txt
pinew --no-github > "$LOG/pinew-offline.txt" 2>&1
check "pinew --no-github succeeds on an existing remote project" grep -q 'Next:' "$LOG/pinew-offline.txt"
check "pinew --no-github leaves all remote refs unchanged" test "$(git -C "$GH/repos/offline.git" show-ref)" = "$before_refs"
check "pinew --no-github makes no GitHub API calls" test "$(wc -l < "$GH/calls.log")" = "$before_calls"
check "pinew keeps unrelated user files untracked" test "$(git ls-files -- unrelated.txt)" = ''
check "pinew leaves unrelated user file contents intact" grep -qx 'user work' unrelated.txt

# A failed installation still leaves the checkout at the requested SHA: checkout equality isn't success.
git -C "$K" switch -q -c chore/retry origin/main
cat > "$K/install.sh" <<'EOF'
#!/usr/bin/env bash
echo attempt >> "$HOME/install-attempts"
[[ -f "$HOME/allow-install" ]]
EOF
git -C "$K" add install.sh; git -C "$K" commit -q -m 'installer retry fixture'; git -C "$K" push -q -u origin chore/retry 2>/dev/null
check "pikit reports an installation failure" bash -c "! '$ROOT/bin/pikit' use chore/retry"
check "status reports a failed install at the current checkout" grep -q 'installation pending' <<<"$("$ROOT/bin/pikit" status)"
touch "$H/allow-install"
"$ROOT/bin/pikit" apply --if-changed --quiet > "$LOG/pikit-retry.txt" 2>&1
check "pikit retries a failed installation at the same SHA" test "$(wc -l < "$H/install-attempts")" = 2
"$ROOT/bin/pikit" apply --if-changed --quiet >/dev/null 2>&1
check "pikit skips a successfully installed unchanged SHA" test "$(wc -l < "$H/install-attempts")" = 2

# Local projects on master, without any GitHub repo yet, must publish the setup.
L="$P/local-first"; git init -q -b master "$L"
git -C "$L" commit --allow-empty -qm base
(cd "$L" && pinew > "$LOG/local-first" 2>&1)
check "first publication includes setup on remote main" git -C "$GH/repos/local-first.git" cat-file -e main:scripts/check.sh
check "first publication retains local master" git -C "$L" rev-parse --verify master
check "local-only legacy setup creates usable main and test" git -C "$P/offline" rev-parse --verify test
(cd "$P/offline" && pi-branch feat/offline > "$LOG/branch-offline" 2>&1)
check "offline proposal can start a feature branch" test "$(git -C "$P/offline" branch --show-current)" = feat/offline
check "offline feature inherits the locally installed project checks" git -C "$P/offline" cat-file -e HEAD:scripts/check.sh
check "offline proposal leaves remote refs unchanged" test "$(git -C "$GH/repos/offline.git" show-ref)" = "$before_refs"

# Only workflow branches enter test. Git must refuse to overwrite a user's untracked file.
cd "$R" || exit 1
git switch -q -c scratch/experiment main
echo experiment > experiment; git add experiment; git commit -qm experiment; sync
check "scratch branches stay out of test" bash -c '! git merge-base --is-ancestor scratch/experiment test'
git switch -q -c fix/collision main
echo feature > collision; git add collision; git commit -qm collision
echo personal > "$T/rebuild-test-checkout/collision"
old_test="$(git rev-parse test)"
check "sync refuses to overwrite an untracked test checkout file" bash -c '! pi-test-branch'
check "untracked checkout file survives sync" grep -qx personal "$T/rebuild-test-checkout/collision"
check "collision leaves test at its old tip" test "$(git rev-parse test)" = "$old_test"
rm -f "$T/rebuild-test-checkout/collision"
sync
check "sync recovers after the collision is cleared" git merge-base --is-ancestor fix/collision test

# A rejected remote rebuild must return failure; retrying should publish the rebuilt tip.
printf '#!/bin/sh\nexit 1\n' > "$GH/repos/rebuild.git/hooks/pre-receive"
chmod +x "$GH/repos/rebuild.git/hooks/pre-receive"
git switch -q main; git branch -q -D fix/collision; git -C "$GH/repos/rebuild.git" branch -q -D fix/collision
check "rebuild reports a remote push rejection" bash -c '! pi-test-branch rebuild'
rm "$GH/repos/rebuild.git/hooks/pre-receive"
pi-test-branch rebuild >/dev/null 2>&1
check "retry publishes the intended rebuild" test "$(git -C "$GH/repos/rebuild.git" rev-parse test)" = "$(git rev-parse test)"
# A clean clone rebuilding test keeps finished remote work even without a local checkout.
git clone -q "$GH/repos/rebuild.git" "$T/second-machine"
git -C "$T/second-machine" switch -qc fix/remote-only
git -C "$T/second-machine" commit --allow-empty -qm remote-work
git -C "$T/second-machine" push -qu origin fix/remote-only
remote_only="$(git -C "$T/second-machine" rev-parse HEAD)"
pi-test-branch rebuild >/dev/null 2>&1
check "rebuild keeps eligible branches published by another clone" git merge-base --is-ancestor "$remote_only" test
before_preview="$(git -C "$GH/repos/rebuild.git" show-ref)"
old_test="$(git rev-parse test)"
pi-test-branch rebuild --dry-run > "$LOG/preview" 2>&1
check "rebuild preview reports the target branch" grep -q 'would rebuild test' "$LOG/preview"
check "rebuild preview preserves local test" test "$(git rev-parse test)" = "$old_test"
check "rebuild preview preserves remote refs" test "$(git -C "$GH/repos/rebuild.git" show-ref)" = "$before_preview"

# An existing user's file and a failed adoption must stay where they were.
mkdir -p "$T/custom dir"
echo sentinel > "$T/custom dir/sentinel"
check "missing live branch is reported" bash -c " ! pi-test-branch live-set --adopt '$T/custom dir' no-such-branch"
check "failed adoption preserves the existing folder" grep -qx sentinel "$T/custom dir/sentinel"
(cd "$R" && pi-branch fix/remote-only >"$LOG/remote-checkout" 2>&1)
check "pi-branch resumes an existing remote branch" test "$(git rev-parse HEAD)" = "$remote_only"
# ---- pr-only guard -----------------------------------------------------------------------------
echo "guards"
ESBUILD=(npx -y esbuild@0.28.2)
command -v esbuild >/dev/null && ESBUILD=(esbuild)
"${ESBUILD[@]}" "$ROOT/global/extensions/web-scope.ts" --bundle --platform=node --format=cjs --outfile="$T/web-scope.cjs" --log-level=error
if "${ESBUILD[@]}" "$ROOT/global/extensions/pr-only.ts" --bundle --platform=node \
	--format=cjs --external:@earendil-works/pi-coding-agent --outfile="$T/pr-only.cjs" --log-level=error >/dev/null 2>&1; then
	cat > "$T/guard.cjs" <<'EOF'
const ext = require(process.argv[2]).default; let h; let branch = "feat/x";
ext({ on: (e, f) => { if (e === "tool_call") h = f; }, exec: async (c, a) => ({ code: 0, stdout: a[0] === "branch" ? branch : "abc" }) });
const web = require(process.argv[3]).default; let filter;
web({on: (_, f) => {filter = f;}, registerCommand: () => {}});
const saved = process.argv;
for (const [ui, allow] of [[true, "read"], [false, "read,write"], [false, "read,mcp__exa__web_search_exa"]]) {
  process.argv = ["node", "pi", "--tools", allow];
  const opts = {selectedTools: ["read", "mcp__exa__web_search_exa"]};
  filter({systemPromptOptions: opts}, {hasUI: ui});
  const wantWeb = !ui && allow.includes("mcp__exa__");
  if (opts.selectedTools.includes("mcp__exa__web_search_exa") !== wantWeb || !opts.selectedTools.includes("read")) throw Error("web-scope role isolation failed");
}
process.argv = saved;
const home = require("os").homedir(); const dev = `${home}/workspace/projects/pi-config/global/MAIN.md`;
const cases = [
  [true, "bash", "gh pr merge 3 --merge", true], [true, "bash", "gh repo delete o/r --yes", true],
  [true, "bash", "git push origin main", true], [true, "bash", "git push origin --delete feat/x", true],
  [true, "bash", "git branch -D feat/x", true], [true, "bash", "gh api -X DELETE repos/o/r/rulesets/5", true],
  [true, "write", { path: `${home}/.pi/agent/AGENTS.md` }, false], [true, "edit", { path: dev }, true],
  [false, "edit", { path: dev }, false], [false, "bash", "git push -u origin feat/x", true],
  [false, "bash", "pinew", true], [false, "bash", "gh pr create --base main --head feat/x", true],
];
(async () => { let bad = 0;
  for (const [want, tool, inp, ui] of cases) {
    const r = await h({ toolName: tool, input: typeof inp === "string" ? { command: inp } : inp }, { cwd: "/tmp", hasUI: ui });
    if (!!(r && r.block) !== want) { bad++; console.log(`guard wrong: ${tool} ${JSON.stringify(inp)} ui=${ui}`); }
  } process.exit(bad ? 1 : 0); })();
EOF
	if node "$T/guard.cjs" "$T/pr-only.cjs" "$T/web-scope.cjs" > "$LOG/guard.txt" 2>&1; then pass "guards block prohibited operations and isolate web tools by role"
	else fail "pr-only guard: $(head -n3 "$LOG/guard.txt" | tr '\n' ' ')"; fi
else
	fail "pr-only guard could not compile (esbuild is required)"
fi

echo
echo "workflow tests: $passes passed, $fails failed"
(( fails == 0 ))
