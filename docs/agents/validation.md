# Validation

Choose local feedback by the affected behavior before finishing a code change. Size alone does not determine scope. A one-line persistence or authentication change can affect several workflows.

| Change | Required validation |
| --- | --- |
| Localized iOS behavior with a clear affected workflow, such as removing a button or adjusting input validation | `./scripts/validate.sh --focused OneSetUITests/Class/testMethod` with existing tests covering the affected behavior. Supply multiple selectors when needed. |
| Appearance-only iOS change, such as copy, spacing, or color | `./scripts/validate-ui.sh --ui-<affected-route>` and screenshot inspection; its app build is sufficient when interaction and navigation are unchanged. |
| Dashboard-only change | `npm --prefix admin run check`, `npm --prefix admin run build`, and `npm --prefix admin test`; include Worker checks when its source-read or authorization boundary changes. |
| Worker-only change | Worker typecheck and relevant API tests using the scripts in `worker/package.json`. |
| Simulator or validation tooling only | Relevant `scripts/tests` tests and a real run of the affected command. |
| Shared models/services, persistence, concurrency, authentication/session logic, schema, dependencies, build configuration, changes spanning iOS and Worker, or unclear impact | Focused checks for the affected behavior, followed by [final validation](#final-validation). |

For a localized iOS change without a relevant existing test, build and exercise the affected behavior in the simulator; add a test when it protects meaningful behavior. When the affected workflows cannot be bounded confidently, use final validation to cover the full suite. Follow the UI verification requirements below when appearance or navigation changes.

Focused validation builds the app and runs only the supplied iOS test selectors. It skips Worker and simulator-tooling tests, reuses `.codex/build/focused/` for incremental builds, and retains each run's logs and `.xcresult`. The default invocation still runs the full suite and reuses `.codex/build/validation/<simulator-UUID>/` for incremental builds. Logs and `.xcresult` results remain separate for each run.

For tasks limited to documentation, agent instructions, configuration examples, or other non-code files that do not affect compilation or execution, review the changed files and any relevant links or examples. Skip build/test scripts and simulator validation for these tasks. For mixed tasks, apply validation to the code or UI changes they include.

- Repair failures with the narrowest relevant check first. For a failed iOS test, use `--focused` with its selector; both `OneSetTests/Suite[/test]` and `OneSetUITests/Class[/testMethod]` are supported. Run Worker or simulator-tooling failures through their own commands. Confirm the repaired checks pass before starting another full suite.
- Inspect the final diff for accidental or unrelated changes.
- Report the chosen scope, why it fits the change, and which checks actually ran and their outcomes. Describe an interrupted run as incomplete. If validation cannot be performed, state exactly what remains unvalidated.

For full or Worker validation, install Worker dependencies first with `npm ci --prefix worker` (Node 22 or later). Full validation also installs the dashboard dependencies with `npm ci --prefix admin`, then runs Astro checks/build/request integration alongside Worker typechecking/API contract tests. It also runs SwiftLint, simulator discovery and recovery regression tests, and the `OneSetTests` and `OneSetUITests` targets. No coverage threshold is defined. Build logs and `.xcresult` results are retained under `.codex/validation/` by default.

All simulator scripts select an available compatible device by UUID, wait for boot readiness and create a replacement when automatic selection cannot boot an existing device. A particular model name is not required. For device overrides, iPad validation, artifact paths, missing runtimes and host/agent permissions, follow [simulator validation and recovery](../simulator-validation.md).

When simulator access or a Swift macro plugin reports a host sandbox denial, retry the same validation with permitted host execution when available. Parsing, typechecking and generic builds do not replace the required build and test run. If host execution is unavailable, report the exact blocker and the recovery steps from that guide. Do not claim that visual or accessibility checks passed unless they actually ran.

Derive application workflow acceptance checks from the approved [requirements](../requirements.md). Track unfinished verification and release decisions in GitHub Issues.

## Final validation

For a PR targeting `main`, GitHub Actions runs the full suite with `./scripts/validate.sh --ci`. This mode builds and tests on a booted simulator with code signing disabled and attaches the Xcode log and test results to the workflow run. Use that run for final full-suite validation. Keep the local focused checks, manual acceptance checks, and screenshot review called for above.

After integration and review fixes, push the final revision. Wait for the **OneSet validation** check on the current PR head, and verify it passed before merging. Use the PR checks view or `gh pr checks <PR> --watch`. Confirm the PR head still matches the revision you validated before merging. If CI fails, inspect its logs and artifacts, verify the fix with the narrowest relevant check, then push and wait for the new revision's result.

For delivery without a PR covered by this workflow, run `./scripts/validate.sh` locally when the change needs the full suite. For a multi-ticket spec, the coordinator owns final validation. Ticket implementers hand off passing checks for their affected behavior and identify integrated validation as pending.

## UI test storage

The UI test setup assigns a fresh `ONESET_UI_TEST_ID` UUID to every test. App composition uses that identity for workout databases, onboarding progress, catalog caches, mock backend files, and preview authentication preferences. App relaunches within a test keep the same identity; another test gets separate storage automatically. Set an explicit second identity only when a journey intentionally models another isolated installation. Existing reset/keep launch flags control state within one journey and are not required to isolate different tests. The environment override is active only in Debug builds.

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
