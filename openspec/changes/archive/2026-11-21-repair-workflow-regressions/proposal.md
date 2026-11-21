## Why
The supplied root-cause fixes still fail recovery paths used to repair this setup. A green happy-path test does not prove rebuild, deleted-branch handling, offline setup or a failed deployment retry works.

## What Changes
- Correct the existing test-branch script's rebuild, fetch and unfinished-change handling.
- Make existing-project pinew respect --no-github and keep unrelated untracked files out of setup commits.
- Record successful deployments so failed installations are retried at the same commit.
- Extend the existing workflow tests to reproduce these failures and require their dependencies.

## Impact
Existing workflow scripts and their tests only. Models, visibility, GitHub merge policy and prompt budgets are out of scope. No new commands or helper scripts.

## How you'll see it work
Run scripts/check.sh with OpenSpec, esbuild and ShellCheck installed. The workflow tests check actual local and bare-remote branch tips, committed file lists and installer invocations, including failed-install retries.
