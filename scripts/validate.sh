#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/validation-common.sh"
oneset_toolchain
oneset_artifacts
python3 -m unittest discover -s scripts/tests -v
SIMULATOR_UDID="$(oneset_simulator)"
DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
RUN_DIR="$ONESET_ARTIFACTS_DIR/validation/$(date +%Y%m%d-%H%M%S)-$$"
BUILD_DIR="$ONESET_ARTIFACTS_DIR/build/validation/$(basename "$RUN_DIR")"

echo "==> Building"
oneset_xcodebuild "$RUN_DIR/build.log" \
  -project OneSet.xcodeproj \
  -scheme OneSet \
  -destination "$DESTINATION" \
  -derivedDataPath "$BUILD_DIR" \
  build

echo "==> Running tests"
oneset_xcodebuild "$RUN_DIR/test.log" \
  -project OneSet.xcodeproj \
  -scheme OneSet \
  -destination "$DESTINATION" \
  -derivedDataPath "$BUILD_DIR" \
  -parallel-testing-enabled NO \
  -resultBundlePath "$RUN_DIR/tests.xcresult" \
  test

echo "==> Validation passed; logs and test results: $RUN_DIR"
