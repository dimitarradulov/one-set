#!/bin/bash
set -euo pipefail

SCHEME="OneSet"
PROJECT="OneSet.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 18 Pro"

echo "==> Building"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  build

echo "==> Running tests"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  test

echo "==> Validation passed"