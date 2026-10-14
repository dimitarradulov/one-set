---
name: implement-spec
description: "Implement the result of /to-spec and /to-tickets in code."
disable-model-invocation: true
---

You have been provided a spec. This spec should have tickets associated with it, describing how to implement the spec.

The issue tracker should have been provided to you. If not, tell the user to run `/setup-matt-pocock-skills`.

The goal is the entire spec implemented on a single **integration branch**, with every ticket resolved the way the issue tracker closes work.

The tickets are not a list of steps. They are a **task graph** with blocking relationships between them. This means there is always a **frontier** of tickets which are ready to be grabbed.

Communication to and from subagents should be sparse. Communicate primarily through **context pointers**: to the spec, tickets, research notes, and previous commits. Don't duplicate information already available via pointers.

**Implementer subagents** should be run in the background where possible for maximum concurrency.

## Steps

1. Read the spec and tickets to understand the task graph.

2. (optional) Use an **exploration subagent** to conduct any exploration required by the tickets - relevant codebase files or external documentation. Ensure the exploration subagent can save files - it should save its markdown notes in a directory outside the repo, accessible by all future subagents. This lets **implementer subagents** focus on implementation rather than exploration.

3. Read the project's [Git workflow](../../../docs/agents/git-workflow.md), record the intended merge target, and create and switch to the integration branch before editing files. Keep all implementation work on that branch or its ticket branches. If the issue tracker closes work through PRs, or the user asks for one, open a draft PR after the first merge in step 5 (a branch with no commits ahead of main can't open one), marked as closing the spec and tickets.

4. Use **implementer subagents** to implement each ticket, each in its own worktree on its own branch. Each implementer subagent:
  - confirms its worktree is based on the integration branch before starting, and resets onto it if not;
  - selects and reads the available skills whose triggers match the ticket, using `tdd` for test-driven implementation and relevant language, framework, and service skills alongside it;
  - for any UI change, always uses the `impeccable` skill/plugin when available, applying its guidance before implementation and during visual review; if unavailable, reports that and follows the project's UI guidance;
  - merges the integration branch tip into its own branch before reporting done.

5. Once an **implementer subagent** completes, merge its work to the integration branch with a **merger subagent**.

6. If this changes the **frontier** of available tickets, kick off more **implementer subagents** to work on the new tickets. This allows for maximum concurrency.

7. Once all tickets are complete, call the Skill tool with `code-review` on the integration branch. Fix all issues raised by the code review in a single **implementer subagent**.

8. Once every ticket is implemented, all review findings are resolved, and the project's required validation passes, merge the integration branch into the recorded target, following the project's Git workflow. If a draft PR exists, mark it ready and merge it when required checks and reviews permit. Resolve each ticket the way the issue tracker closes work, and report the merge result. If a required check or review blocks merging, report the blocker and leave the branch ready for completion.

9. Clean up all **implementer subagent** worktrees.
