---
description: (used automatically by the kit) finish a merge that stopped on conflicts
argument-hint: "<what is being merged>"
---
You are finishing a merge. This folder is a throwaway git worktree in the middle of merging `$1`;
the user never resolves conflicts — you do, now, without asking.

1. `git status` and `git diff` to see every conflicted file.
2. Understand both sides: `git log --oneline -15 MERGE_HEAD` and `-15 HEAD`, the OpenSpec changes
   involved (`openspec/changes/`), and each side's diff of the conflicted files.
3. Resolve every file keeping **both** sides' intended behavior; drop a side only when it's clearly
   obsolete. Remove every conflict marker.
4. Run `scripts/check.sh` if it can run here without installing anything; fix the resolution if it fails.
5. `git add` the resolved files, then `git commit --no-edit`.

Stay in this folder: don't push, switch branches, rebase or reset. If the two sides truly contradict
each other, say so in one paragraph and stop without committing.

Final reply: one line per file — how you resolved it.
