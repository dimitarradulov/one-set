# Validation


Run `./scripts/validate.sh` from the repository root before finishing, as specified in the [root commands](../../AGENTS.md#commands).

- Fix failures introduced by your changes and rerun validation after fixes.
- Inspect the final diff for accidental or unrelated changes.
- Report which checks actually ran and their outcomes. If validation cannot be performed, state exactly what remains unvalidated.

The validation script invokes both an Xcode build and tests. The project currently has no test target or committed automated test suite; this limits validation until test support is configured. No coverage threshold is defined.

Treat the application workflows in the [launch checklist](../launch-checklist.md) as future acceptance checks.

## UI changes

For changes to SwiftUI views, layout, styling, navigation, spacing, typography, colors, icons, or visual state, also run:

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
