#!/bin/bash
set -euo pipefail

OUTPUT_DIR=".codex/screenshots"
NAME="${1:-current}"

mkdir -p "$OUTPUT_DIR"

OUTPUT_PATH="$OUTPUT_DIR/$NAME.png"

echo "==> Capturing simulator screenshot"

xcrun simctl io booted screenshot "$OUTPUT_PATH"

echo "==> Screenshot saved to:"
echo "$OUTPUT_PATH"