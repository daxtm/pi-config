## Why
The earlier checks missed ordinary commit hooks, existing project layouts and checkout collisions. These paths can publish unintended history, lose a user's untracked file or report success while a remote operation failed.

## What Changes
Correct the existing project setup, branch sync, deploy status and slash-command paths. Add regression coverage using local repositories. Verify the installer and Pi delegation independently.

## Impact
The changes affect workflow scripts and their prompts. Models, subscriptions and GitHub visibility choices are outside scope. Run scripts/check.sh to observe setup, remote branch tips, retained user files, refusal paths and successful retries.
