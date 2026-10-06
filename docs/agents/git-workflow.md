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
