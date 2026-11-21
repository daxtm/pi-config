#!/usr/bin/env bash
# The project's checks: everything that must pass before a PR can merge. Run by pi's build agent
# locally and by GitHub Actions (.github/workflows/ci.yml) on every PR — one script, same result.
#
# Rules for whoever fills this in (usually the build agent, in the first change that adds code):
#   - work on a fresh clone: install dependencies first (npm ci, uv sync, pip install -e ., ...)
#   - non-interactive, exits non-zero on any failure
#   - tests, then lint/typecheck, then build — whatever the project has
set -euo pipefail
cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.."

# --- replace from here ---
if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::warning::scripts/check.sh has no project checks yet"; fi
echo "no project checks yet (fill in scripts/check.sh)"
