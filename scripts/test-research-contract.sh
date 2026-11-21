#!/usr/bin/env bash
# Offline contract checks for the research scoping rules (ADR-0005, openspec change
# standalone-research). Text-contract regression checks only: they verify the contract clauses
# are present in the prompt/agent files, and fail on in-memory fixtures with a clause removed.
# They do NOT prove runtime model behavior.
set -uo pipefail
ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

fail=0

has() { # label content pattern — pattern is a fixed string on a single line
	local label="$1" content="$2" pattern="$3"
	if ! grep -qF -- "$pattern" <<<"$content"; then
		echo "FAIL $label: missing contract clause: $pattern"
		return 1
	fi
	return 0
}

check_research() { # global/prompts/research.md
	local label="$1" c="$2" rc=0
	has "$label" "$c" 'Run `researcher` with only: "$@"' || rc=1
	has "$label" "$c" 'Delegate the question alone' || rc=1
	has "$label" "$c" 'If `$@` is empty, ask what to research' || rc=1
	has "$label" "$c" 'Standalone (default)' || rc=1
	has "$label" "$c" 'Never call read/grep/find/ls/bash' || rc=1
	has "$label" "$c" 'report that instead of using local' || rc=1
	has "$label" "$c" 'explicitly names this project' || rc=1
	has "$label" "$c" 'read-only' || rc=1
	has "$label" "$c" 'no sizing line' || rc=1
	has "$label" "$c" 'Active work keeps its goal' || rc=1
	has "$label" "$c" 'a few sentences plus sources' || rc=1
	has "$label" "$c" 'up to 3 researchers in parallel' || rc=1
	return "$rc"
}

check_researcher() { # global/agents/researcher.md
	local label="$1" c="$2" rc=0
	has "$label" "$c" 'name: researcher' || rc=1
	has "$label" "$c" 'tools: read, grep, find, ls, bash, mcp__exa__web_search_exa' || rc=1
	has "$label" "$c" 'Web-only by default' || rc=1
	has "$label" "$c" 'You never modify files' || rc=1
	has "$label" "$c" 'Local tools (`read`/`grep`/`find`/`ls`/`bash`): default OFF' || rc=1
	has "$label" "$c" 'never substitute them for missing web sources' || rc=1
	has "$label" "$c" 'report the web failure instead' || rc=1
	has "$label" "$c" 'scopes a named repository, path, or project feature' || rc=1
	has "$label" "$c" '"in this project"' || rc=1
	has "$label" "$c" 'read-only, strictly' || rc=1
	has "$label" "$c" 'Never write, install or delete' || rc=1
	has "$label" "$c" 'not consent to inspect the local codebase' || rc=1
	return "$rc"
}

check_main() { # global/MAIN.md
	local label="$1" c="$2" rc=0
	has "$label" "$c" '`/research <question>` skips sizing' || rc=1
	has "$label" "$c" 'answer-only' || rc=1
	has "$label" "$c" 'delegate the question alone' || rc=1
	has "$label" "$c" 'return a few' || rc=1
	has "$label" "$c" 'No sizing line, branching, planning, edits, or task updates' || rc=1
	has "$label" "$c" 'the active task keeps its goal' || rc=1
	has "$label" "$c" 'never apply findings unless the user separately asks' || rc=1
	has "$label" "$c" 'web by default; local look-ups only when explicitly scoped' || rc=1
	return "$rc"
}


main() {
	local research researcher
	research="$(<"$ROOT/global/prompts/research.md")"
	researcher="$(<"$ROOT/global/agents/researcher.md")"
	mainc="$(<"$ROOT/global/MAIN.md")"

	check_research "global/prompts/research.md" "$research" || fail=1
	check_researcher "global/agents/researcher.md" "$researcher" || fail=1
	check_main "global/MAIN.md" "$mainc" || fail=1

	# Negative fixtures: in-memory copies with a required clause removed must fail the checks.
	# (research.md minus the standalone/no-local-tools/non-steering clauses)
	local broken
	broken="$(grep -v -e 'Standalone (default)' -e 'Never call read/grep/find/ls/bash' \
		-e 'no sizing line' -e 'report that instead of using local' <<<"$research")"
	if check_research "negative:research.md" "$broken" >/dev/null 2>&1; then
		echo "FAIL negative fixture: research.md checks pass without the scope/no-steering clauses"
		fail=1
	fi
	# (researcher.md minus the local-tool restriction / scoped exception)
	broken="$(grep -v -e 'default OFF' -e 'scopes a named repository' -e 'never substitute them' \
		-e 'report the web failure instead' <<<"$researcher")"
	if check_researcher "negative:researcher.md" "$broken" >/dev/null 2>&1; then
		echo "FAIL negative fixture: researcher.md checks pass without the local-tool restriction"
		fail=1
	fi


	# (MAIN.md minus the answer-only sizing exception)
	broken="$(grep -v -e 'skips sizing' -e 'answer-only' -e 'keeps its goal' <<<"$mainc")"
	if check_main "negative:MAIN.md" "$broken" >/dev/null 2>&1; then
		echo "FAIL negative fixture: MAIN.md checks pass without the sizing exception"
		fail=1
	fi

	if (( fail == 0 )); then
		echo "ok   research contract checks (research, researcher, MAIN + negatives)"
	fi
	return "$fail"
}

main
