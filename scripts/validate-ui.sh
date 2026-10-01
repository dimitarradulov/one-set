#!/bin/bash
set -euo pipefail

SCHEME="OneSet"
PROJECT="OneSet.xcodeproj"
DEVICE="iPhone 18 Pro"
BUNDLE_ID="com.oneset.OneSet"

UI_ROUTE="${1:-}"

if [[ -z "$UI_ROUTE" ]]; then
  echo "Usage:"
  echo "  ./scripts/validate-ui.sh --ui-home"
  echo "  ./scripts/validate-ui.sh --ui-settings"
  echo "  ./scripts/validate-ui.sh --ui-workout-detail"
  exit 1
fi

SCREENSHOT_NAME="${UI_ROUTE#--ui-}"

echo "==> Booting simulator"

xcrun simctl boot "$DEVICE" 2>/dev/null || true

ACTIVE_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
DEVICE_UI_APP=""

for candidate in \
  "$ACTIVE_DEVELOPER_DIR/../Applications/DeviceHub.app" \
  "$ACTIVE_DEVELOPER_DIR/Applications/Simulator.app"; do
  if [[ -d "$candidate" ]]; then
    DEVICE_UI_APP="$candidate"
    break
  fi
done

if [[ -n "$DEVICE_UI_APP" ]]; then
  echo "==> Opening $(basename "$DEVICE_UI_APP" .app)"
  open "$DEVICE_UI_APP" 2>/dev/null || true
else
  echo "Could not find Device Hub or Simulator in selected Xcode: $ACTIVE_DEVELOPER_DIR" >&2
  exit 1
fi

echo "==> Building app"

BUILD_DIR=".codex/build"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH=$(find "$BUILD_DIR/Build/Products" -name "*.app" -type d | head -n 1)

if [[ -z "$APP_PATH" ]]; then
  echo "Could not find built .app"
  exit 1
fi

echo "==> Installing app"

xcrun simctl install booted "$APP_PATH"

echo "==> Launching app with route: $UI_ROUTE"

xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true

xcrun simctl launch \
  booted \
  "$BUNDLE_ID" \
  "$UI_ROUTE"

sleep 2

echo "==> Capturing screenshot"

./scripts/screenshot.sh "$SCREENSHOT_NAME"

echo "==> UI validation ready"
echo ".codex/screenshots/$SCREENSHOT_NAME.png"
