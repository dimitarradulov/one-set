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
if [[ -n "${2:-}" ]]; then
  ONESET_SIMULATOR_UDID="$2"
fi
oneset_run() {
  oneset_capture_screenshot "$1"
}
oneset_with_simulator oneset_run "$NAME"
