#!/bin/bash
set -euo pipefail

source "$(dirname "$0")/validation-common.sh"
NAME="${1:-current}"
if [[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo "Screenshot name must contain only letters, digits, underscores or hyphens." >&2
  exit 1
fi
oneset_toolchain
oneset_artifacts
OUTPUT_DIR="$ONESET_ARTIFACTS_DIR/screenshots"
if [[ -n "${2:-}" ]]; then
  ONESET_SIMULATOR_UDID="$2"
fi
SIMULATOR_UDID="$(oneset_simulator)"

mkdir -p "$OUTPUT_DIR"

OUTPUT_PATH="$OUTPUT_DIR/$NAME.png"

echo "==> Capturing simulator screenshot"

xcrun simctl io "$SIMULATOR_UDID" screenshot "$OUTPUT_PATH"

echo "==> Screenshot saved to:"
echo "$OUTPUT_PATH"
