# Validation

Run `./scripts/validate.sh` from the repository root before finishing a task that changes code, including application code, tests, or executable scripts. Changes to build configuration that affect compilation or test execution also require this validation.

For tasks limited to documentation, agent instructions, configuration examples, or other non-code files that do not affect compilation or execution, review the changed files and any relevant links or examples. Skip build/test scripts and simulator validation for these tasks. For mixed tasks, apply validation to the code or UI changes they include.

- Fix failures introduced by your changes and rerun validation after fixes.
- Inspect the final diff for accidental or unrelated changes.
- Report which checks actually ran and their outcomes. If validation cannot be performed, state exactly what remains unvalidated.

Install Worker dependencies first with `npm ci --prefix worker` (Node 22 or later). The validation script invokes an Xcode build, the `OneSetUITests` target, simulator discovery/recovery regression tests, and Worker typechecking/API contract tests. No coverage threshold is defined. Build logs and `.xcresult` results are retained under `.codex/validation/` by default.

All simulator scripts select an available compatible device by UUID, wait for boot readiness and create a replacement when automatic selection cannot boot an existing device. A particular model name is not required. For device overrides, iPad validation, artifact paths, missing runtimes and host/agent permissions, follow [simulator validation and recovery](../simulator-validation.md).

When simulator access or a Swift macro plugin reports a host sandbox denial, retry the same validation with permitted host execution when available. Parsing, typechecking and generic builds do not replace the required build and test run. If host execution is unavailable, report the exact blocker and the recovery steps from that guide. Do not claim that visual or accessibility checks passed unless they actually ran.

Treat the application workflows in the [launch checklist](../launch-checklist.md) as future acceptance checks.

## UI changes

Run UI validation only when the task changes visible appearance or screen behavior that needs visual verification: for example, adding a screen or visible element, redesigning a screen, changing layout or styling, or changing a visible state or navigation flow.

Editing a SwiftUI file alone does not require UI validation. Refactors that preserve appearance and screen behavior, or changes confined to models, persistence, services, or other nonvisual logic, require code validation only.

For UI changes that need visual verification, also run:

```sh
./scripts/validate-ui.sh --ui-program-overview
```

Replace `--ui-program-overview` with an existing route for the affected screen/state from `AppLaunchConfiguration.swift`.

The script must build and launch the app in the iOS Simulator, open the affected screen/state, capture a screenshot in `.codex/screenshots/` (or the configured artifact directory), and make it available for visual inspection. A simulator window is opened when available; screenshot capture also works without the GUI.

Inspect the screenshot for spacing, alignment, clipping, overlap, typography, colors, and safe areas. Compare it with a reference design when one exists. Fix any issues and rerun UI validation until the result is visually correct.

## Simulator routes

When implementing or modifying a screen that needs visual validation:

- Reuse an existing `--ui-*` launch argument for the affected screen/state, or add one if needed.
- Use stable preview/mock data so the route opens the screen/state directly without manual navigation.
- Limit routes to development/testing behavior; they must not alter production behavior.
- Ensure `validate-ui.sh` launches the appropriate route before capturing the screenshot.

Current routes include `--ui-welcome`, `--ui-preferences`, `--ui-program-overview`, and `--ui-workout-preview`; `AppLaunchConfiguration.swift` is authoritative. Add specific state routes when needed, such as `--ui-workout-empty`, `--ui-workout-loading`, or `--ui-workout-error`.
