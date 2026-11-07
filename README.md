# OneSet

OneSet is an iOS workout app for lifters who want to follow a simple HIT program: prepare with warmups, perform one hard working set per exercise, and record what happened so the next workout starts with useful history.

The initial audience already knows basic gym movements. OneSet supplies curated programs, exercise videos, compact progression guidance, and a reliable logbook. It does not claim that one-set training is universally superior.

## The experience

1. Continue with Apple, Google, or email from the welcome screen to create an account or sign in.
2. Choose kg/lb and training frequency, then select one of ten programs.
3. Start a seven-day trial; intended price afterward is $4.89/month, subject to actual storefront pricing.
4. Open the program overview, organized by training week and Day 1/Day 2 rather than weekdays.
5. Train with previous performance beside simple weight/reps inputs. Save locally immediately; sync automatically when possible.
6. Finish, optionally add a note, and see the next workout. History and remembered substitutions survive program changes.

Warmups are recommendations, not extra log entries. Users can replace an exercise on request for one session or remember the choice. Rest timers start automatically after completed sets. Offline training and session recovery are core requirements. Videos download only when a workout is opened on Wi-Fi; already downloaded clips remain available offline.

## Launch scope

All ten gym-only programs in the [program library](docs/HIT_Workout_Program_Library.md) ship with a recommended eight training weeks; continuing afterward is allowed. Workout and exercise history, editable performance, optional notes on completed sessions, and subscription management are included.

Use one training device at a time; synced history can be restored on a replacement device. Current templates are editable and started/completed sessions keep their recorded content.

Deferred: nutrition, social feeds, custom programs/exercises, charts, Apple Watch, warmup logging, extra working sets/intensity-technique logging, CSV export, soft deletion/recovery UI, administration beyond the founder's catalog dashboard, and session replay.

A separate, laptop-first web dashboard hosted on Cloudflare for the founder's complete text-catalog maintenance workflow is approved for design and is not yet implemented. Edit, review, and publish during one visit, with no saved drafts or autosave. Cloudflare Access will restrict entry to the founder's exact email using email-code login, with sessions configured for up to one month. Technical design must automate consistency between the catalog files, published content, and bundled fallback. The current YAML and preview/publish commands remain available; see [catalog publishing](docs/catalog-publishing.md).

## Documentation

Start with [requirements](docs/requirements.md) for the approved product scope. Use [domain language](GLOSSARY.md) when terms such as cycle, occurrence and session are unclear. The [program library](docs/HIT_Workout_Program_Library.md) is the source for the ten workouts.

For iOS code structure, follow [iOS architecture](docs/agents/architecture.md). For implementation, read [system design](docs/system-design.md), then the focused [database design](docs/database/README.md), [sync and recovery](docs/sync-and-recovery.md), and [API contracts](docs/api-contracts.md). Follow [validation guidance](docs/agents/validation.md) for checks; track unfinished work and release decisions in GitHub Issues.

The [DBML schema](docs/database/oneset.dbml) and [applied migration](docs/database/migrations/001_documented_schema.sql) are technical artifacts, not additional product specifications. Requirements govern product behavior; the technical documents describe proposed implementation where no code exists yet.

## Architecture and budget

Swift / SwiftUI → durable local storage → Cloudflare Worker → Neon Postgres. Clerk owns account profiles and access; payment integration remains to be specified; PostHog records a limited event list. Private R2 holds exercise videos, delivered through an authorized Worker with deliberate cache rules.

For the current native email-code sign-in setup and Apple/Google provider prerequisites, see [Clerk development setup](docs/clerk-development.md).

Start on Neon Free. Aim for free infrastructure, with a broader $5–10/month target. Independent backups are approved only if they add no cost. Free allowances, actual video sizes and backup sizes must be verified before activation. No absolute zero-loss or zero-cost guarantee has been established.

## Project status

The approved product scope and proposed implementation are documented. The database schema was applied to the `oneset` database in Neon project `wispy-bird-47588933` on 2026-09-29. SwiftUI onboarding uses feature-level observable models and an injected bundled catalog. Clerk native Apple, Google OAuth, and email authentication and the [account setup lookup](docs/account-setup.md) are implemented; the lookup requires a configured development Worker and creates the Neon account identity link on sign-in or session restoration. Account-scoped unfinished onboarding saves locally on Continue and resumes after restart, including when setup lookup is offline. Completed setup saves locally before overview, queues upload for offline use, and restores across devices after upload. The completed-setup Worker requires migration 002 before deployment; durable local workout recording and automatic completed-session uploads are implemented. Development deployment and live verification are recorded in [Worker setup](worker/README.md). The focused onboarding sequence is approved; its earlier prototype is not in this checkout.

## iOS development

Open [OneSet.xcodeproj](OneSet.xcodeproj) in Xcode and run the `OneSet` scheme on an iOS simulator. OneSet supports iOS/iPadOS 26.0 and newer on iPhone and iPad. This baseline was selected on 2026-11-01 to focus support and compatibility testing on current platform generations. App and test targets share the 26.0 minimum; both device families remain enabled.

The release-build baseline is Xcode 27.2 (27B52), the iOS 27.2 SDK, and Swift 6 language mode. This meets [Apple’s SDK submission minimum](https://developer.apple.com/news/upcoming-requirements/?id=04282026a). Pinned dependencies remain unchanged: ClerkKit 1.5.8, GRDB 7.11.1, Nuke 13.2.0 and PhoneNumberKit 5.0.11. Their declared iOS minimums are below 26. Compatibility evidence is tracked in [issue #22](https://github.com/dimitarradulov/one-set/issues/22). The 2026-11-01 checks passed six core workflows on iOS 26.0 iPhone 16 and iPad Air 11-inch (M3), and on iOS 27.2 iPad Pro 13-inch (M5). These cover email sign-in, onboarding recovery, recording/discard, offline completion/relaunch, pending-workout sign-out, and setup upload/restoration. The current iOS 27.2 iPhone full run passed 63 UI journeys and 52 Swift tests; Worker typechecking and all 37 API tests also passed. The unsigned generic iOS Release build passed.

The shared palette and Dynamic Type-aware font styles live in [OneSet/DesignSystem](OneSet/DesignSystem). Use `OneSetColors` and `OneSetTypography` in SwiftUI views rather than repeating color values or font names. Change their definitions there when the design system changes. The Bebas Neue and Montserrat font files and license notices are in `OneSet/DesignSystem/Fonts`; font registration is in [Config/Info.plist](Config/Info.plist).

For a command-line simulator build, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project OneSet.xcodeproj -scheme OneSet \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

If Xcode is already selected with `xcode-select`, the `DEVELOPER_DIR` prefix can be omitted. Device builds require an Apple development team and an available bundle identifier.

Install API dependencies with `npm ci --prefix worker` (Node 22 or later), then run `./scripts/validate.sh` for the full build, UI tests and Worker typecheck/API contract tests. Use `./scripts/validate.sh --focused OneSetUITests/Class/testMethod` for localized iOS changes, following the [validation scope guidance](docs/agents/validation.md). See [Worker development setup](worker/README.md) for the API endpoint and identity configuration. Run `./scripts/setup-simulator.sh` to select or create a compatible simulator and wait for it to boot. See [simulator validation and recovery](docs/simulator-validation.md) for iPad checks, screenshots, missing runtimes and agent permissions.
