# Implementation plan: Per-exercise warmup

## Overview
Move warmup guidance into a sheet reachable from each workout exercise, with optional load estimates based on a previous or user-entered planned weight. The agreed proposal is [issue #73](https://github.com/dimitarradulov/one-set/issues/73); implementation tasks are tracked as GitHub sub-issues.

## Decisions
- Start in the active session, which already has previous-performance data. Keep existing detail guidance until the preview also supports the sheet.
- Show the relevant exercise's captured or catalog guidance. Preserve snapshots and avoid inventing weights. A planned weight is temporary guidance input and never records a set.
- Preview should use previous performance only when reliably available; otherwise use percentages and optional entry. Do not introduce unsafe data assumptions.

## Ordered task index
1. [#74: Active workout sheet](https://github.com/dimitarradulov/one-set/issues/74)
2. [#75: Preview sheet](https://github.com/dimitarradulov/one-set/issues/75) - blocked by #74.
3. [#76: Complete move and update documentation](https://github.com/dimitarradulov/one-set/issues/76) - blocked by #75; includes the end-to-end checkpoint and human review.

## Checkpoints
- After #75: verify both workout paths, previous and absent weights, editable estimate, and preserved set data before removing detail guidance.
- After #76: complete the selected validation and simulator inspection; review with the user before closing the parent issue.

## Risks and open questions
- Existing session snapshots and remote catalog content can differ. Present the relevant exercise's captured guidance; do not silently substitute a generic string. Escalate conflicting product guidance if needed.
- Previous-performance availability in preview needs investigation; the percentage-only fallback is specified in #75.
- The working tree contains unrelated changes; preserve them and follow repository Git workflow before implementation.
