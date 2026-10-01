# OneSet

OneSet is a SwiftUI iOS app for following curated HIT workout programs and recording training sessions.

## Commands

Run from the repository root:

```sh
# Build for the iOS Simulator without code signing.
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project OneSet.xcodeproj -scheme OneSet \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build

# Required validation before finishing any task.
./scripts/validate.sh
```

## Task guidance

- Before changing product behavior or design, read [sources of truth](docs/agents/project-context.md).
- When adding or refactoring SwiftUI features, domain models, persistence, or services, follow [iOS architecture](docs/agents/architecture.md).
- When editing documentation or configuration examples, follow [documentation conventions](docs/agents/documentation.md).
- When changing the schema or migrations, follow [database changes](docs/agents/database.md).
- Before finishing any DEVELOPMENT task, i.e. writing code, follow [validation](docs/agents/validation.md); UI changes also require simulator routes and screenshot inspection.
- When committing or preparing a pull request, follow [Git workflow](docs/agents/git-workflow.md).
