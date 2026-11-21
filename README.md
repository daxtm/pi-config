# Pi config v3

Ask for the behavior you want. Main handles tiny edits and gives clear implementation work to one builder. Use /propose for design, /apply for an approved spec, /roadmap for milestones and /research for an independent answer. One debugger can investigate a persistent failure. Model assignments are in agent-models.conf.

The builder exercises the real entry point. A direct feat branch marks its final commit with a Pi-Ready: yes trailer. Planned branches finish their OpenSpec tasks. The test branch runs pi-check on the combined commit before moving the preview. /ship merges current main, archives finished changes, verifies the final commit locally and opens the PR. The owner merges and chooses which branches to delete. Local verification covers use of the kit; GitHub cannot enforce a local result on a manually opened PR.

Run pi-check --force HEAD to repeat a committed check. New scaffolds accept documentation only until a builder adds the project tests to scripts/check.sh. /cleanup preserves tips outside origin/main. pinew upgrades original project templates and preserves customized files. Inspect customized CI separately. Existing test history can be refreshed with pi-test-branch rebuild after reviewing --dry-run.

For a reproducible kit defect, run pikit repair with the failing command and its error as a description. It uses an isolated config worktree, the configured builder, the local gate and a separate PR. Merge the fix, deploy with pikit apply, which retries the original command once if its checkout still matches (supply the command and arguments after the description). Live configuration is generated from the deployed checkout. User settings and authentication are retained.
