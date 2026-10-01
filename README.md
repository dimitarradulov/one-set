# OneSet

OneSet is an iOS workout app for lifters who want to follow a simple HIT program: prepare with warmups, perform one hard working set per exercise, and record what happened so the next workout starts with useful history.

The initial audience already knows basic gym movements. OneSet supplies curated programs, exercise videos, compact progression guidance, and a reliable logbook. It does not claim that one-set training is universally superior.

## The experience

1. Create an account with Apple or email.
2. Choose kg/lb and training frequency, then select one of ten programs.
3. Start a seven-day trial; intended price afterward is $4.89/month, subject to actual storefront pricing.
4. Open the program overview, organized by training week and Day 1/Day 2 rather than weekdays.
5. Train with previous performance beside simple weight/reps inputs. Save locally immediately; sync automatically when possible.
6. Finish, optionally add a note, and see the next workout. History and remembered substitutions survive program changes.

Warmups are recommendations, not extra log entries. Users can replace an exercise on request for one session or remember the choice. Rest timers start automatically after completed sets. Offline training and session recovery are core requirements. Videos download only when a workout is opened on Wi-Fi; already downloaded clips remain available offline.

## Launch scope

All ten gym-only programs in the [program library](docs/HIT_Workout_Program_Library.md) ship with a recommended eight training weeks; continuing afterward is allowed. Workout and exercise history, editable performance, exercise notes, optional session notes, and subscription management are included.

Use one training device at a time; synced history can be restored on a replacement device. Current templates are editable and started/completed sessions keep their recorded content.

Deferred: nutrition, social feeds, custom programs/exercises, charts, Apple Watch, warmup logging, extra working sets/intensity-technique logging, CSV export, soft deletion/recovery UI, admin app, and session replay.

## Documentation

Start with [requirements](docs/requirements.md) for the approved product scope. Use [domain language](CONTEXT.md) when terms such as cycle, occurrence and session are unclear. The [program library](docs/HIT_Workout_Program_Library.md) is the source for the ten workouts.

For implementation, read [system design](docs/system-design.md), then the focused [database design](docs/database/README.md), [sync and recovery](docs/sync-and-recovery.md), and [API contracts](docs/api-contracts.md). The [launch checklist](docs/launch-checklist.md) tracks remaining verification and release gates.

The [DBML schema](docs/database/oneset.dbml) and [applied migration](docs/database/migrations/001_documented_schema.sql) are technical artifacts, not additional product specifications. Requirements govern product behavior; the technical documents describe proposed implementation where no code exists yet.

## Architecture and budget

Swift / SwiftUI → durable local storage → Cloudflare Worker → Neon Postgres. Clerk owns account profiles and access; payment integration remains to be specified; PostHog records a limited event list. Private R2 holds exercise videos, delivered through an authorized Worker with deliberate cache rules.

Start on Neon Free. Aim for free infrastructure, with a broader $5–10/month target. Independent backups are approved only if they add no cost. Free allowances, actual video sizes and backup sizes must be verified before activation. No absolute zero-loss or zero-cost guarantee has been established.

## Project status

The approved product scope and proposed implementation are documented. The database schema was applied to the `oneset` database in Neon project `wispy-bird-47588933` on 2026-09-29. A minimal SwiftUI app scaffold now exists; account, workout, local storage, sync, and backend behavior are still to be implemented. The focused onboarding sequence is approved; its earlier prototype is not in this checkout.

## iOS development

Open [OneSet.xcodeproj](OneSet.xcodeproj) in Xcode and run the `OneSet` scheme on an iOS simulator. The project currently uses Swift 6 and a provisional iOS 17 deployment target. Confirm the device and SDK floor before release as tracked in the [launch checklist](docs/launch-checklist.md).

The shared palette and Dynamic Type-aware font styles live in [OneSet/DesignSystem](OneSet/DesignSystem). Use `OneSetColors` and `OneSetTypography` in SwiftUI views rather than repeating color values or font names. Change their definitions there when the design system changes. The Bebas Neue and Montserrat font files and license notices are in `OneSet/DesignSystem/Fonts`; font registration is in [Config/Info.plist](Config/Info.plist).

For a command-line simulator build, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project OneSet.xcodeproj -scheme OneSet \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

If Xcode is already selected with `xcode-select`, the `DEVELOPER_DIR` prefix can be omitted. Device builds require an Apple development team and an available bundle identifier.
