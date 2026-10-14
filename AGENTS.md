# OneSet

OneSet is a SwiftUI iOS app for following curated HIT workout programs and recording training sessions.

## Commands

Run from the repository root:

```sh
# Build for the iOS Simulator without code signing.
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project OneSet.xcodeproj -scheme OneSet \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Full validation; choose the scope using docs/agents/validation.md.
./scripts/validate.sh

# Focused validation for a small iOS change.
./scripts/validate.sh --focused OneSetUITests/OnboardingJourneyTests/testLoginOffersEmailCodeFlowAndReturnsToWelcome
```

## Task guidance

- Before changing product behavior or design, read [sources of truth](docs/agents/project-context.md).
- When adding or refactoring SwiftUI features, domain models, persistence, or services, follow [iOS architecture](docs/agents/architecture.md).
- When editing documentation or configuration examples, follow [documentation conventions](docs/agents/documentation.md).
- When changing the schema or migrations, follow [database changes](docs/agents/database.md).
- When changing code, follow [validation](docs/agents/validation.md) before finishing. Documentation-only and other non-code tasks require review of the changed files, not build/test scripts. Simulator routes and screenshot inspection are required only for UI changes that need visual verification, such as new screens, redesigns, or new visible elements.
- Before starting concurrent implementation, committing, or preparing a pull request, follow [Git workflow](docs/agents/git-workflow.md).

## Agent skills

### Cloudflare

Use the Cloudflare CLI workflow for Workers, CDN, and R2 object storage. Do not use or add Cloudflare MCP servers, including documentation servers. Use the project's Wrangler installation in `worker/`; for operations Wrangler does not support, call the Cloudflare REST API from the terminal. See [Cloudflare CLI workflow](docs/agents/cloudflare.md).

### Issue tracker

Issues and specs live in GitHub Issues; use the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical roles use the default label strings. See `docs/agents/triage-labels.md`.

### Domain docs

Domain docs use a single-context layout rooted at `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md`.
