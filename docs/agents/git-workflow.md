# Git workflow

## Concurrent implementation

Give each concurrent implementation task its own branch and sibling Git worktree, created from the intended committed base. Run all edits and validation from that worktree. For example, from the original repository:

```sh
git worktree add -b codex/task-name ../one-set-task-name HEAD
cd ../one-set-task-name
```

Leave existing uncommitted edits in their original checkout. If a task depends on those edits, agree on a handoff and committed base before starting dependent implementation. Review the complete diff in the task's worktree.

Worktrees isolate files and build artifacts. Simulator scripts separately coordinate access to shared simulator devices; see [simulator validation](../simulator-validation.md).

## Commits and pull requests

Before committing, run `git diff --check` to catch whitespace errors.

In pull requests:

- Summarize the affected requirements or design decisions.
- Link a related issue when one exists.
- List validation performed.
- Include screenshots for visual design changes.
- Call out any migration or production-data impact explicitly.

## Cleanup after implementation

After implementation, validation, and the authorized delivery are complete, remove the task's temporary worktree and local branch before handing back the task. Run cleanup from the primary checkout, leaving it on `main`.

1. Verify the task worktree is clean and its commits are preserved in the delivery target or a remote branch. If work remains uncommitted or only on the local branch, retain it and report the remaining delivery step.
2. Remove the task worktree with `git worktree remove <path>`, then delete its local branch with `git branch -d <branch>`. If deletion fails because delivery used squash or rebase, verify the delivered changes before using `git branch -D <branch>`.
3. Run `git worktree prune`, then verify with `git worktree list` and `git branch --list` that the task worktree and branch are gone.

Preserve the primary checkout, other active tasks, and remote branches. Explicit user requests to delete worktrees or branches authorize cleanup of those named resources even when their commits have not been delivered.

## Delivery and status

Establish the delivery target from the user's request or the invoked workflow. Editing alone does not require committing, pushing, or merging. For a request to push the current task, commit that task's changes first when needed, then push those commits. Stage explicit paths or hunks so unrelated work stays separate. Preserve the scope of earlier authorization across follow-up messages.

Before delivery, inspect the working tree and compare the branch with its upstream. Confirm that the task's changes are included in the commits being delivered. After pushing or merging, verify the resulting local and remote references rather than inferring success from a command being started.

For issue-driven work, reconcile completed tickets using the invoked workflow's completion criteria. Close children when their required implementation, review, validation, and delivery are complete; close the parent when the integrated outcome is complete. Keep unfinished tickets open with their exact remaining work. Use the [issue tracker](issue-tracker.md) commands.

In the final response, state the task's commit or that changes are uncommitted, the branch, validation result, merge target and whether it was reached, whether commits were pushed, and the state of related issues. Distinguish an integration branch from local `main` and remote `main`. Identify task changes left outside the delivery, if any.
