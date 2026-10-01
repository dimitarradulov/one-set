# Validation

Run `./scripts/validate.sh` from the repository root before finishing a task that changes code, including application code, tests, or executable scripts. Changes to build configuration that affect compilation or test execution also require this validation.

For tasks limited to documentation, agent instructions, configuration examples, or other non-code files that do not affect compilation or execution, review the changed files and any relevant links or examples. Skip build/test scripts and simulator validation for these tasks. For mixed tasks, apply validation to the code or UI changes they include.

- Fix failures introduced by your changes and rerun validation after fixes.
- Inspect the final diff for accidental or unrelated changes.
- Report which checks actually ran and their outcomes. If validation cannot be performed, state exactly what remains unvalidated.

The validation script invokes both an Xcode build and tests. The project currently has no test target or committed automated test suite; this limits validation until test support is configured. No coverage threshold is defined.

Treat the application workflows in the [launch checklist](../launch-checklist.md) as future acceptance checks.

## UI changes

Run UI validation only when the task changes visible appearance or screen behavior that needs visual verification: for example, adding a screen or visible element, redesigning a screen, changing layout or styling, or changing a visible state or navigation flow.

Editing a SwiftUI file alone does not require UI validation. Refactors that preserve appearance and screen behavior, or changes confined to models, persistence, services, or other nonvisual logic, require code validation only.

For UI changes that need visual verification, also run:

```sh
./scripts/validate-ui.sh --ui-home
```

Replace `--ui-home` with the route for the affected screen/state.

The script must build and launch the app in the iOS Simulator, open the affected screen/state, capture a screenshot in `.codex/screenshots/`, and make it available for visual inspection.

Inspect the screenshot for spacing, alignment, clipping, overlap, typography, colors, and safe areas. Compare it with a reference design when one exists. Fix any issues and rerun UI validation until the result is visually correct.

## Simulator routes

When implementing or modifying a screen that needs visual validation:

- Reuse an existing `--ui-*` launch argument for the affected screen/state, or add one if needed.
- Use stable preview/mock data so the route opens the screen/state directly without manual navigation.
- Limit routes to development/testing behavior; they must not alter production behavior.
- Ensure `validate-ui.sh` launches the appropriate route before capturing the screenshot.

Example screen routes are `--ui-home`, `--ui-workout`, `--ui-workout-detail`, and `--ui-settings`. Add specific state routes when needed, such as `--ui-workout-empty`, `--ui-workout-loading`, or `--ui-workout-error`.
