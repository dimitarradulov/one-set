#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/validation-common.sh"

VALIDATION_MODE=full
TEST_FILTERS=()
if [[ "${1:-}" == --focused ]]; then
  VALIDATION_MODE=focused
  shift
  if [[ "$#" -eq 0 ]]; then
    echo "Focused validation requires at least one OneSetUITests/Class[/testMethod] selector." >&2
    exit 1
  fi
  for selector in "$@"; do
    if [[ ! "$selector" =~ ^OneSetUITests/[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?$ ]]; then
      echo "Invalid test selector: $selector. Use OneSetUITests/Class[/testMethod]." >&2
      exit 1
    fi
    TEST_FILTERS+=("-only-testing:$selector")
  done
elif [[ "$#" -ne 0 ]]; then
  echo "Usage: ./scripts/validate.sh [--focused OneSetUITests/Class[/testMethod] ...]" >&2
  exit 1
fi
export VALIDATION_MODE

oneset_toolchain
oneset_artifacts
if [[ "$VALIDATION_MODE" == full ]]; then
  python3 -m unittest discover -s scripts/tests -v
  npm --prefix worker run typecheck
  npm --prefix worker test
fi
oneset_run() {
  DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
  RUN_DIR="$ONESET_ARTIFACTS_DIR/validation/$(date +%Y%m%d-%H%M%S)-$$"
  BUILD_DIR="$ONESET_ARTIFACTS_DIR/build/validation/$(basename "$RUN_DIR")"
  if [[ "$VALIDATION_MODE" == focused ]]; then
    BUILD_DIR="$ONESET_ARTIFACTS_DIR/build/focused/$SIMULATOR_UDID"
  fi

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
    "$@" test

  echo "==> $VALIDATION_MODE validation passed; logs and test results: $RUN_DIR"
}
if [[ "$VALIDATION_MODE" == focused ]]; then
  oneset_with_simulator oneset_run "${TEST_FILTERS[@]}"
else
  oneset_with_simulator oneset_run
fi
