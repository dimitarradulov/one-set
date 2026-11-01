# Task completion

For an action request, finish the requested edits and required validation before handing the task back. An inspection result or an active validation run is a progress update. Continue through the remaining authorized steps, including after a status question or interruption. Ask only when a missing decision or permission prevents the next action.

For work spanning long checks or several stages, keep a short checkpoint under `.codex/tasks/<task-name>.md`. Record the worktree, branch, current revision, changed files, remaining actions, and active validation command/session and artifact paths. Update it before a handoff or interruption when possible. On recovery, inspect the recorded processes and files before restarting work.

Before finishing:

1. Account for every requested outcome in the final diff or an explicit blocker. Preserve unrelated edits.
2. Finish the checks selected by [validation](validation.md). Follow its failure-repair sequence before repeating a full suite.
3. Complete the authorized delivery steps in [Git workflow](git-workflow.md#delivery-and-status), including issue reconciliation for issue-driven work.
4. Report the implemented outcome, checks and any remaining blocker. For code delivery, include the Git and issue status from that workflow. If an external dependency prevents completion, leave a checkpoint with the exact next action and state what remains unfinished.
