#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/validation-common.sh"

VALIDATION_MODE=full
TEST_FILTERS=()
if [[ "${1:-}" == --focused ]]; then
  VALIDATION_MODE=focused
  shift
  if [[ "$#" -eq 0 ]]; then
      echo "Focused validation requires at least one OneSetTests/Suite[/test] or OneSetUITests/Class[/testMethod] selector." >&2
    exit 1
  fi
  for selector in "$@"; do
    if [[ ! "$selector" =~ ^OneSet(UITests|Tests)/[A-Za-z_][A-Za-z0-9_]*(/[A-Za-z_][A-Za-z0-9_]*)?$ ]]; then
      echo "Invalid test selector: $selector. Use OneSetTests/Suite[/test] or OneSetUITests/Class[/testMethod]." >&2
      exit 1
    fi
    TEST_FILTERS+=("-only-testing:$selector")
  done
elif [[ "$#" -eq 1 && "$1" == --ci ]]; then
  VALIDATION_MODE=ci
elif [[ "$#" -ne 0 ]]; then
  echo "Usage: ./scripts/validate.sh [--ci | --focused OneSetTests/Suite[/test] or OneSetUITests/Class[/testMethod] ...]" >&2
  exit 1
fi
export VALIDATION_MODE

oneset_toolchain
oneset_artifacts
if [[ "$VALIDATION_MODE" != focused ]]; then
  python3 -m unittest discover -s scripts/tests -v
  npm ci --prefix admin
  npm --prefix admin run check
  npm --prefix admin run build
  npm --prefix admin test
  npm --prefix worker run typecheck
  npm --prefix worker test
fi
if [[ "$VALIDATION_MODE" == ci ]]; then
  oneset_xcodebuild "$ONESET_ARTIFACTS_DIR/validation/ci-build.log" \
    -project OneSet.xcodeproj -scheme OneSet \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$ONESET_ARTIFACTS_DIR/build/ci" CODE_SIGNING_ALLOWED=NO build
  exit
fi

oneset_run() {
  DESTINATION="platform=iOS Simulator,id=$SIMULATOR_UDID"
  RUN_DIR="$ONESET_ARTIFACTS_DIR/validation/$(date +%Y%m%d-%H%M%S)-$$"
  BUILD_DIR="$ONESET_ARTIFACTS_DIR/build/validation/$SIMULATOR_UDID"
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
  local test_status=0
  oneset_xcodebuild "$RUN_DIR/test.log" \
    -project OneSet.xcodeproj \
    -scheme OneSet \
    -destination "$DESTINATION" \
    -derivedDataPath "$BUILD_DIR" \
    -parallel-testing-enabled NO \
    -resultBundlePath "$RUN_DIR/tests.xcresult" \
    "$@" test || test_status=$?

  if [[ "$test_status" -ne 0 ]]; then
    echo "==> Tests failed or were interrupted; results: $RUN_DIR/tests.xcresult" >&2
    echo "Repair and rerun failed selectors with ./scripts/validate.sh --focused <selector> before repeating the full suite." >&2
    return "$test_status"
  fi

  echo "==> $VALIDATION_MODE validation passed; logs and test results: $RUN_DIR"
}
if [[ "$VALIDATION_MODE" == focused ]]; then
  oneset_with_simulator oneset_run "${TEST_FILTERS[@]}"
else
  oneset_with_simulator oneset_run
fi
