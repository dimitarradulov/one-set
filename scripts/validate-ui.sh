#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/validation-common.sh"

UI_ROUTE="${1:-}"
if [[ ! "$UI_ROUTE" =~ ^--ui-[a-z-]+$ ]] || ! grep -Fq -- "\"$UI_ROUTE\"" OneSet/App/AppLaunchConfiguration.swift; then
  echo "Supply an existing route from OneSet/App/AppLaunchConfiguration.swift, e.g.:" >&2
  echo "  ./scripts/validate-ui.sh --ui-program-overview" >&2
  exit 1
fi

oneset_toolchain
oneset_artifacts
oneset_run() {
  UI_ROUTE="$1"
  RUN_DIR="$ONESET_ARTIFACTS_DIR/validation/ui-$(date +%Y%m%d-%H%M%S)-$$"
  BUILD_DIR="$ONESET_ARTIFACTS_DIR/build/ui/$(basename "$RUN_DIR")"
  BUNDLE_ID="com.oneset.OneSet"
  SCREENSHOT_NAME="${UI_ROUTE#--ui-}-${ONESET_SIMULATOR_FAMILY:-iphone}"

  # GUI opening is convenient; CoreSimulator can build/launch/capture without it.
  for candidate in \
    "$DEVELOPER_DIR/../Applications/DeviceHub.app" \
    "$DEVELOPER_DIR/Applications/Simulator.app"; do
    if [[ -d "$candidate" ]]; then
      open "$candidate" || echo "Could not open simulator window; continuing with simctl." >&2
      break
    fi
  done

  echo "==> Building app on $SIMULATOR_UDID"
  oneset_xcodebuild "$RUN_DIR/build.log" \
    -project OneSet.xcodeproj -scheme OneSet \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -derivedDataPath "$BUILD_DIR" build

  APP_PATH="$BUILD_DIR/Build/Products/Debug-iphonesimulator/OneSet.app"
  if [[ ! -d "$APP_PATH" ]]; then
    echo "Built app missing at $APP_PATH" >&2
    exit 1
  fi
  xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

  if [[ -n "${ONESET_CONTENT_SIZE:-}" ]]; then
    ORIGINAL_CONTENT_SIZE="$(xcrun simctl ui "$SIMULATOR_UDID" content_size)"
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP
    trap 'xcrun simctl ui "$SIMULATOR_UDID" content_size "$ORIGINAL_CONTENT_SIZE" || true' EXIT
    xcrun simctl ui "$SIMULATOR_UDID" content_size "$ONESET_CONTENT_SIZE"
    SCREENSHOT_NAME="$SCREENSHOT_NAME-$ONESET_CONTENT_SIZE"
  fi

  echo "==> Launching $UI_ROUTE on $SIMULATOR_UDID"
  # A not-running app is expected; install/launch errors still fail validation.
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" "$UI_ROUTE"
  sleep 2
  oneset_capture_screenshot "$SCREENSHOT_NAME"
  echo "==> UI validation ready for inspection; build log: $RUN_DIR/build.log"
}
oneset_with_simulator oneset_run "$UI_ROUTE"
