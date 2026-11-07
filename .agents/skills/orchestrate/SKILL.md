---
name: orchestrate
description: Run or control Issue Orchestrator for the current GitHub repository.
disable-model-invocation: true
---

Use the installed `issue-orchestrator` CLI from the target repository. Read the repository's orchestrator config when explaining its settings.

- Start or recover a batch with `issue-orchestrator run`. To target one issue, use `issue-orchestrator run --issue N`.
- Inspect progress with `issue-orchestrator status`.
- Use `pause`, `resume`, `stop N`, and `tell N MESSAGE` for operator requests.
- Use `retry N` for an explicit retry after the batch has finished.
- Report the blocker and PR link when the controller hands back an issue. Keep the controller's GitHub checks and repository protections in force.
