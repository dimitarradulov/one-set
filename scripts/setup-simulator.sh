#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/validation-common.sh"
if [[ "$#" -gt 1 ]] || [[ "$#" -eq 1 && "$1" != --download-runtime ]]; then
  echo "Usage: ./scripts/setup-simulator.sh [--download-runtime]" >&2
  exit 1
fi
oneset_toolchain
if [[ "${1:-}" == --download-runtime ]]; then
  echo "==> Installing iOS simulator runtime (may take several GB)" >&2
  xcodebuild -downloadPlatform iOS >&2
fi
oneset_simulator
