# Repository Guidelines

## Project Structure & Sources of Truth

OneSet has a minimal SwiftUI app in `OneSet/` with an Xcode project at `OneSet.xcodeproj`; the API has not been implemented. Start with `README.md` for status and reading order. `docs/requirements.md` defines approved product behavior, `CONTEXT.md` defines domain terms, and `docs/HIT_Workout_Program_Library.md` defines the ten programs. `DESIGN.md` covers the proposed UI. Implementation proposals live in `docs/system-design.md`, `docs/sync-and-recovery.md`, and `docs/api-contracts.md`. Database artifacts are in `docs/database/`: `oneset.dbml`, its design notes, and numbered SQL migrations under `migrations/`.

## Development & Validation Commands

Build the `OneSet` scheme with Xcode, or run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project OneSet.xcodeproj -scheme OneSet -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` from the repository root. Use `rg --files` to list tracked and untracked files, `rg "term" docs CONTEXT.md DESIGN.md` to check terminology and related decisions, and `git diff --check` to catch whitespace errors before a commit. Review Markdown links and code examples in changed documents.

## Style & Naming

Write concise Markdown with descriptive headings, relative links, and two-space nested list indentation. Use the terms in `CONTEXT.md`: a **workout template** prescribes work, while a **session** records an attempt. Keep requirements distinct from design proposals and label assumptions needing validation. Use lowercase, hyphenated names for new prose files; follow the numbered migration pattern, such as `002_description.sql`. SQL uses two-space indentation and `snake_case` tables and columns. No formatter or linter is configured.

## Testing & Database Changes

No committed automated test suite or coverage threshold exists. The initial schema was checked with DBML parsing and disposable PostgreSQL/PGlite SQL checks; those checks are documented in `docs/database/README.md`, but their runner is not in this checkout. For schema changes, update the DBML, design notes, and a new reviewed migration together; rehearse against disposable data and document the checks performed. Do not edit an already applied migration to represent a new change. Treat application workflows in `docs/launch-checklist.md` as future acceptance checks.

## Commits & Pull Requests

Git history contains only an `Initial commit`, so no established commit format exists. Use short, descriptive subjects that name the change. In pull requests, summarize the affected requirements or design decisions, link a related issue when one exists, list validation performed, and include screenshots for visual design changes. Call out any migration or production-data impact explicitly.

## Configuration & Secrets

Keep credentials out of commits. `.gitignore` excludes `.env` files except `.env.example`; document required variables with placeholders only.
