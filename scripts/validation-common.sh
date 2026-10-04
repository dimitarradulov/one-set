#!/bin/bash
# Shared by simulator, build, UI and screenshot entry points.
ONESET_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ONESET_ROOT"

oneset_toolchain() {
  if [[ "$(uname -s)" != Darwin ]]; then
    echo "iOS validation requires a macOS host with Xcode. See docs/simulator-validation.md." >&2
    return 1
  fi
  if [[ -z "${DEVELOPER_DIR:-}" ]]; then
    DEVELOPER_DIR="$(xcode-select -p 2>/dev/null || true)"
    if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
      for candidate in /Applications/Xcode.app/Contents/Developer /Applications/Xcode*.app/Contents/Developer; do
        if [[ -x "$candidate/usr/bin/xcodebuild" ]]; then
          DEVELOPER_DIR="$candidate"
          break
        fi
      done
    fi
  fi
  if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
    echo "Full Xcode was not found. Set DEVELOPER_DIR to your Xcode.app/Contents/Developer. See docs/simulator-validation.md." >&2
    return 1
  fi
  export DEVELOPER_DIR
  echo "==> Xcode: $DEVELOPER_DIR" >&2
  if ! xcodebuild -checkFirstLaunchStatus; then
    echo "Finish Xcode setup: open Xcode, accept its license and install requested components, then rerun. See docs/simulator-validation.md." >&2
    return 1
  fi
  if ! xcrun --sdk iphonesimulator --show-sdk-path >/dev/null; then
    echo "The iOS Simulator SDK is missing. Install iOS platform support in Xcode > Settings > Components." >&2
    return 1
  fi
  if ! command -v python3 >/dev/null; then
    echo "Python 3 is required; install Xcode command-line tools through Xcode setup." >&2
    return 1
  fi
  # Swift macro plugins use sandbox-exec. Detect nested sandbox denial before compiling.
  if [[ -x /usr/bin/sandbox-exec ]] && ! /usr/bin/sandbox-exec -p '(version 1)(allow default)' /usr/bin/true; then
    echo "Swift macro sandbox cannot start under current host/agent permissions. Retry with host execution permitted or run ./scripts/validate.sh in macOS Terminal. See docs/simulator-validation.md." >&2
    return 1
  fi
}

oneset_simulator() {
  local options=(--family "${ONESET_SIMULATOR_FAMILY:-iphone}" --boot-timeout "${ONESET_SIMULATOR_BOOT_TIMEOUT:-180}")
  if [[ -n "${ONESET_SIMULATOR_UDID:-}" ]]; then
    options+=(--udid "$ONESET_SIMULATOR_UDID")
  fi
  python3 "$ONESET_ROOT/scripts/simulator.py" "${options[@]}"
}

oneset_artifacts() {
  local write_probe
  ONESET_ARTIFACTS_DIR="${ONESET_ARTIFACTS_DIR:-$ONESET_ROOT/.codex}"
  if ! mkdir -p "$ONESET_ARTIFACTS_DIR" || ! write_probe="$(mktemp "$ONESET_ARTIFACTS_DIR/.write-check.XXXXXX")"; then
    echo "Cannot write validation artifacts. Retry with ONESET_ARTIFACTS_DIR=/tmp/oneset-validation or permit host execution; see docs/simulator-validation.md." >&2
    return 1
  fi
  rm "$write_probe"
  ONESET_ARTIFACTS_DIR="$(cd "$ONESET_ARTIFACTS_DIR" && pwd)"
  export ONESET_ARTIFACTS_DIR
}

oneset_xcodebuild() {
  local log="$1"
  shift
  mkdir -p "$(dirname "$log")"
  local status=0
  xcodebuild ONLY_ACTIVE_ARCH=YES "$@" 2>&1 | tee "$log" || status=$?
  if [[ "$status" -ne 0 ]]; then
    echo "Xcode failed (exit $status). Full log: $log" >&2
    if grep -Eqi 'sandbox.*(Operation not permitted|deny)|sandbox_apply' "$log"; then
      echo "Host/agent sandbox blocked the build. Retry with host execution permitted or run the same script in macOS Terminal; see docs/simulator-validation.md." >&2
    fi
    return "$status"
  fi
}
