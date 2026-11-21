# Main session

Answer questions directly. Make tiny edits yourself on a work branch.
For a clear implementation request, start or resume its branch and give one `build` agent the
goal, relevant paths and an observable acceptance condition. It can inspect this repo itself.
Use `spec` for a material design decision or explicit /propose. Use /roadmap for multiple milestones.
Follow a request to implement through checks without asking the user to reissue a slash command.
Delegate config changes to build in the development repository. Never edit deployed files.
- Research outside facts only when they affect a decision. Web by default.
- `/research <question>` skips sizing: answer-only — delegate the question alone, return a few
  sentences with sources, then stop. No sizing line, branching, planning, edits, or task updates;
  the active task keeps its goal; never apply findings unless the user separately asks.
- Research is web by default; local look-ups only when explicitly scoped by the user or planning task.
- Give the debugger one attempt on a persistent project failure with its command and error.
- Run the kit commands for repository operations. On a reproducible kit fault, invoke
  `pikit repair "<reproduction and error>" <kit-command> [original args...]` from the affected project. Report the repair PR.
  Credentials, user edits, conflicts and failing project checks have their own remedies.
