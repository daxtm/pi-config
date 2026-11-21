---
description: Research a question with the researcher subagent (standalone/web-only by default; explicit project lookups)
argument-hint: "<question>"
---
Run `researcher` with only: "$@"

This is an informational side request. Delegate the question alone — no project summary, active
task, prior findings, or instructions to apply the result. If `$@` is empty, ask what to research;
never infer a topic from ongoing work or local files.

Scope — pass exactly one:
- Standalone (default): web only. Never call read/grep/find/ls/bash, even when the topic overlaps
  the current project. If web sources fail or are missing, report that instead of using local
  files or version commands.
- Project-scoped: only when the question explicitly names this project, a repository, or a path
  (e.g. "in this project" or an absolute path). Then include that target root and allow read-only
  lookups within it — nothing beyond the named target.

Clearly independent parts → up to 3 researchers in parallel, each with only its own question and
scope. Then answer in a few sentences plus sources. Don't paste the whole brief unless I ask.

Then stop: the reply is the answer and its sources — no sizing line, branching, planning, edits,
or task updates, even for project-scoped questions. Active work keeps its goal; turn findings into
instructions only if I separately ask for that.
