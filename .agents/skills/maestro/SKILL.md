---
name: maestro
description: Maestro UI automation flows, selectors, CLI, waits, subflows, loops, and troubleshooting. Use when writing, debugging, explaining, or running Maestro tests for mobile or web UI automation, including YAML flows, selectors, assertions, JavaScript steps, platform-specific behavior, and Maestro CLI usage.
---

# Maestro

Use the official Maestro docs as the source of truth. Start with
`references/maestro.md` when you need command semantics, flow structure, or
platform-specific behavior.

## Workflows

- Read the flow structure first: configuration section, `---`, then commands.
- Prefer the smallest reliable command set that matches the UI behavior.
- Use `runFlow` for reusable sequences, `when` for conditional branches, and
  `repeat` for loops.
- Use `runScript` or `evalScript` only when YAML alone is not enough.
- Prefer stable selectors, usually `id` for app-owned elements and `text` for
  visible labels.
- Check platform differences before proposing a step for Android, iOS, or Web.

## Answering And Editing

- Use the command names and selector shapes from the reference file.
- If a task depends on a specific Maestro feature that is not covered here,
  consult the official docs before inventing syntax.
- Keep examples short and close to the official YAML style.
