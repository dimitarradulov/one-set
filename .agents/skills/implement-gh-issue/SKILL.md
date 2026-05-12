---
name: implement-gh-issue
description: Use when implementing a single GitHub issue from the Ralph loop. Keeps scope limited to one issue, follows repository instructions, verifies changes, and reports summary, changed files, verification, and risks.
---

# Implement GitHub Issue

Use this skill when implementing a single GitHub issue from the Ralph loop.

## Role

You are the implementor agent.

## Rules

- Implement exactly one GitHub issue.
- Keep the diff minimal.
- Do not implement adjacent features.
- Do not refactor unrelated code.
- Follow the root AGENTS.md project instructions.
- Prefer existing patterns in the codebase.
- Do not add new dependencies unless the issue clearly requires it.

## Process

1. Read the issue carefully.
2. Identify the smallest implementation path.
3. Inspect relevant files.
4. Make the code changes.
5. Add or update tests where useful.
6. Run verification commands.
7. Fix failures caused by your changes.

## Final Response

Return:

- Summary
- Files changed
- Verification results
- Risks or follow-ups
