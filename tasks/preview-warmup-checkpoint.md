# Preview warmup visibility

Checkout: /Users/dimitarradulov/Dev/one-set. Branch: main. Base: d7c2dbb. Changes are uncommitted; no push, merge or issue requested.

Removed preview Warmup controls and their unused state and inputs. Updated the three preview call sites, WarmupSheetTests, docs/requirements.md and DESIGN.md. Preserved existing edits in shared files.

Changed files: OneSet/Features/Programs/WorkoutTemplatePreviewScreen.swift, OneSet/Features/Onboarding/OnboardingFlowView.swift, OneSet/Features/Onboarding/CompletedSetupTabsView.swift, OneSetUITests/WarmupSheetTests.swift, docs/requirements.md, DESIGN.md.

Diff whitespace check passed. Both validation commands stopped before building with `sandbox-exec: sandbox_apply: Operation not permitted`. Focused process 86865 exited 1; visual validation also exited 1. No fresh screenshots or test results exist. Host execution is unavailable. The preferred .codex/tasks checkpoint path is also write-protected in this session.

Remaining: run `./scripts/validate.sh --focused OneSetUITests/WarmupSheetTests` and `./scripts/validate-ui.sh --ui-workout-preview` in macOS Terminal or a host-permitted agent session. Inspect the generated screenshot. No commit or delivery authorized.
