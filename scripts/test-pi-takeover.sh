#!/usr/bin/env bash
# Credential-free behavioral tests for bin/pi-takeover: throwaway fixtures in a temp dir (a work
# repo, a bare repo as its origin, a stub `gh` on PATH) — no network, no real credentials.
# Refusals must exit nonzero without mutating anything; the happy path must land both remote
# branches at the captured HEAD with the checkout unchanged. Run by scripts/check.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
TAKEOVER="$ROOT/bin/pi-takeover"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fails=0
fail() { echo "FAIL $*"; fails=$((fails + 1)); }
ok()   { echo "ok   $*"; }
end()  { (( fails == 0 )) && echo "ok   pi-takeover behavior" || { echo "FAIL pi-takeover behavior ($fails failures)"; exit 1; }; }

mkdir -p "$tmp/stub" "$tmp/stub-broken"
cat > "$tmp/stub/gh" <<'EOF'
#!/usr/bin/env bash
# fake gh: authenticated, resolves a repo, accepts every api call (pi-gh-setup runs for real here)
case "$1" in
	auth) exit 0 ;;
	repo) [[ "$*" == *nameWithOwner* ]] && { echo "octo/example"; exit 0; }
	      [[ "$*" == *visibility* ]] && { echo PUBLIC; exit 0; }
	      exit 1 ;;
	api)  exit 0 ;;
esac
exit 1
EOF
chmod +x "$tmp/stub/gh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$tmp/stub-broken/gh"   # gh present but failing
chmod +x "$tmp/stub-broken/gh"

make_repo() { # dir — a work repo with one commit; prints its HEAD
	git init -q -b trunk "$1"
	git -C "$1" config user.email test@example.com
	git -C "$1" config user.name test
	echo example > "$1/README.md"
	git -C "$1" add README.md
	git -C "$1" commit -qm baseline
	git -C "$1" rev-parse HEAD
}
with_origin() { # dir — give the repo a fresh bare origin
	git init -q --bare "$1-origin.git"
	git -C "$1" remote add origin "$1-origin.git"
}
run_takeover() { PATH="$tmp/stub:$PATH" "$TAKEOVER" "$1"; }
refuse() { # label dir — expect nonzero exit, and that origin still has no main/test
	local label="$1" dir="$2" out rc
	if out="$(run_takeover "$dir" 2>&1)"; rc=$?; [[ $rc -ne 0 ]]; then
		ok "$label refuses (exit $rc)"
	else
		fail "$label: expected nonzero exit, got success: $out"; return
	fi
	if git -C "$dir" ls-remote origin refs/heads/main refs/heads/test 2>/dev/null | grep -q .; then
		fail "$label: remote branches were created despite refusal"
	else
		ok "$label: no remote branch created"
	fi
}

# ---- not a git repo -------------------------------------------------------------------------
mkdir -p "$tmp/plain"
if out="$(run_takeover "$tmp/plain" 2>&1)"; rc=$?; [[ $rc -ne 0 ]]; then ok "not a repo refuses (exit $rc)"
else fail "not a repo: expected nonzero exit, got success: $out"; fi

# ---- gh fails ---------------------------------------------------------------------------------
d="$tmp/gh-fail"; make_repo "$d" >/dev/null; with_origin "$d"
if out="$(PATH="$tmp/stub-broken:$PATH" "$TAKEOVER" "$d" 2>&1)"; rc=$?; [[ $rc -ne 0 ]]; then
	ok "gh failure refuses (exit $rc)"
else fail "gh failure: expected nonzero exit, got success: $out"; fi
if git -C "$d" ls-remote origin refs/heads/main refs/heads/test 2>/dev/null | grep -q .; then
	fail "gh failure: remote branches were created despite refusal"
else ok "gh failure: no remote branch created"; fi

# ---- remote main exists → refuse, don't create test --------------------------------------------
d="$tmp/has-main"; head="$(make_repo "$d")"; with_origin "$d"
git -C "$d" push -q origin "$head":refs/heads/main
out="$(run_takeover "$d" 2>&1)" && { echo "$out" >&2; fail "existing main: expected refusal"; } || true
grep -q main <<<"$out" || fail "existing main: diagnostic doesn't name the branch"
if git -C "$d" ls-remote --exit-code origin refs/heads/test >/dev/null 2>&1; then
	fail "existing main: test was created anyway"
else ok "existing main: test not created"; fi

# ---- happy path: both branches at HEAD, checkout untouched, local branches preserved ------------
d="$tmp/happy"; head="$(make_repo "$d")"; with_origin "$d"
echo more >> "$d/README.md"                    # a second commit: HEAD moves past the first
git -C "$d" add README.md; git -C "$d" commit -qm second
head="$(git -C "$d" rev-parse HEAD)"
git -C "$d" branch main "$head^"               # local main elsewhere: must not select the baseline
echo uncommitted > "$d/scratch.txt"            # dirty file: must survive
status_before="$(git -C "$d" status --porcelain)"
out="$(run_takeover "$d" 2>&1)" || { echo "$out" >&2; fail "happy path exited nonzero"; end; exit 1; }
for ref in main test; do
	sha="$(git -C "$d" ls-remote origin "refs/heads/$ref" | cut -f1)"
	[[ "$sha" == "$head" ]] || fail "happy path: origin/$ref is ${sha:-missing}, expected $head"
done
[[ "$(git -C "$d" rev-parse HEAD)" == "$head" ]] || fail "happy path: local HEAD moved"
[[ "$(git -C "$d" status --porcelain)" == "$status_before" ]] || fail "happy path: checkout was modified"
[[ "$(git -C "$d" rev-parse main)" == "$(git -C "$d" rev-parse "$head^")" ]] || fail "happy path: local main moved"
grep -qF "pi-branch chore/repo-baseline" <<<"$out" || fail "happy path: next-step command missing from output"
grep -qF "octo/example" <<<"$out" || fail "happy path: pi-gh-setup output missing"
ok "happy path: both branches at $head, checkout untouched, handoff printed"

# ---- re-run after a successful takeover → refuse, branches unchanged ----------------------------
out="$(run_takeover "$d" 2>&1)" && rc=0 || rc=$?
[[ $rc -ne 0 ]] || fail "re-run: expected nonzero exit, got success"
grep -q main <<<"$out" || fail "re-run: diagnostic doesn't name the conflict"
for ref in main test; do
	sha="$(git -C "$d" ls-remote origin "refs/heads/$ref" | cut -f1)"
	[[ "$sha" == "$head" ]] || fail "re-run: origin/$ref moved to ${sha:-missing}"
done
ok "re-run refuses, both branches unchanged"

end
