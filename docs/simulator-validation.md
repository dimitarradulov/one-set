# Simulator validation and recovery

Use a local macOS host with full Xcode and an installed iOS simulator runtime. Simulator selection is automatic; a particular iPhone model name is not required.

## Everyday commands

```sh
# Select/create a compatible iPhone, wait for readiness, print its UUID.
./scripts/setup-simulator.sh

# Build and run the scheme's UI tests, plus simulator regression tests.
./scripts/validate.sh

# Launch an existing preview route and save its screenshot.
./scripts/validate-ui.sh --ui-program-overview

# Use an iPad, even if an iPhone is also booted.
ONESET_SIMULATOR_FAMILY=ipad ./scripts/validate-ui.sh --ui-program-overview

# Capture an accessibility Dynamic Type size; restore the original afterward.
ONESET_CONTENT_SIZE=accessibility-extra-extra-extra-large \
  ./scripts/validate-ui.sh --ui-program-overview
```

The scripts can run from any working directory. Preview routes are defined in [AppLaunchConfiguration.swift](../OneSet/App/AppLaunchConfiguration.swift); unknown routes fail before building. Screenshots include the device family and requested content size in their filename.

| Optional variable | Behavior |
| --- | --- |
| `DEVELOPER_DIR` | Explicit Xcode `Contents/Developer` directory. An invalid explicit value fails instead of silently selecting another installation. |
| `ONESET_SIMULATOR_FAMILY` | `iphone` (default) or `ipad`. |
| `ONESET_SIMULATOR_UDID` | Exact simulator UUID. Must be available and compatible with the selected family and deployment target; errors never silently switch this override. |
| `ONESET_SIMULATOR_BOOT_TIMEOUT` | Positive readiness timeout in seconds per device; default 180. |
| `ONESET_ARTIFACTS_DIR` | Build, log, test-result and screenshot root; default repository `.codex`. Use an absolute writable directory when agent permissions protect `.codex`. |
| `ONESET_CONTENT_SIZE` | Optional `simctl ui content_size` value for `validate-ui.sh`, such as `accessibility-extra-extra-extra-large`. |

Selection uses available iOS runtimes meeting the project's deployment targets, newest first. It prefers booted devices and reusable `OneSet Validation` devices within each runtime. Every build, install, launch and screenshot uses the selected UUID. Readiness uses `simctl bootstatus -b` with a timeout. Automatic selection tries up to two existing devices, then creates compatible devices from installed runtime/device types with at most two creation attempts per runtime. Recovery preserves existing simulator data and does not restart the shared CoreSimulator service.

Build logs and `.xcresult` test results are saved under `.codex/validation/<run>/`. Validation and UI preview builds use separate derived-data directories. UI testing disables parallel simulator clones. Avoid running two validation commands against the same simulator concurrently; they can interrupt each other's app sessions. Use distinct UUIDs and artifact directories when concurrent runs are needed.

## First-time host setup

1. Install full Xcode in `/Applications` and open it once.
2. Accept the license and install the components Xcode requests. If the script reports unfinished setup, complete it in Xcode or run `xcodebuild -runFirstLaunch` in Terminal; macOS may request administrator authorization.
3. Install iOS platform support and a simulator runtime in Xcode > Settings > Components. Apple's [component installation guide](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components) also documents the command-line path. To download the iOS runtime and then boot a device, run:

   ```sh
   ./scripts/setup-simulator.sh --download-runtime
   ```

   The download can use several GB and requires network access. Normal validation does not initiate large downloads automatically.
4. Run `./scripts/setup-simulator.sh`, then `./scripts/validate.sh`.

If Command Line Tools are selected instead of full Xcode, the scripts locate `/Applications/Xcode.app` or another installed `/Applications/Xcode*.app` for this process. They do not change global `xcode-select` settings. To choose a particular installation:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/validate.sh
```

## Agent permissions and Swift macro failures

“Simulator not found” can mean that the agent cannot connect to CoreSimulator, even when a simulator exists on the host. “Operation not permitted” while starting a Swift macro plugin can also be a host sandbox restriction. A generic simulator destination still needs compiler plugins and does not solve a host permission failure.

The scripts check Xcode setup, SDK availability and whether a compiler-style sandbox subprocess can start. `simctl` errors distinguish permission/service connection failures from missing runtimes. These checks catch common failures early; an unrestricted probe cannot prove that a different agent permission profile will work. Build errors retain their full logs and nonzero exit status.

1. Run `./scripts/setup-simulator.sh` in the agent session and read its error. If it reports a permission denial, use an allowed host execution approval for the same script when the agent supports that flow.
2. If the agent cannot obtain host execution, run `./scripts/validate.sh` in macOS Terminal from the repository root. This checks whether the restriction belongs to the agent session or the host installation.
3. If Terminal succeeds, configure the agent session to permit these host commands and rerun inside that session. In Codex CLI, `/permissions` opens the permissions picker; the IDE extension has a permissions control below the composer. Full access removes the sandbox boundary for trusted local work. Choose it only if that is the intended permission level; it grants broader host access. See official [OpenAI sandbox documentation](https://learn.chatgpt.com/docs/sandboxing). Changing approval policy alone does not remove the sandbox.
4. If only artifact writes are denied, try:

   ```sh
   ONESET_ARTIFACTS_DIR=/tmp/oneset-validation ./scripts/validate.sh
   ```

   This changes the output directory; it does not grant CoreSimulator or compiler-plugin permissions.

Scripts cannot grant themselves access forbidden by the execution environment. They do not change agent permissions, disable Swift macro sandboxing, or substitute parsing/typechecking for a successful build and test run.

## A simulator still will not boot

1. Check the reported Xcode directory and run `xcrun simctl list runtimes` with the same `DEVELOPER_DIR`. Install a compatible runtime if none is available.
2. Clear an obsolete `ONESET_SIMULATOR_UDID` override and rerun `./scripts/setup-simulator.sh` to allow automatic recovery. To intentionally select a different device, get its UUID from `xcrun simctl list devices available`.
3. Check available disk space with `df -h /`. Free space if the runtime, device creation or build reports insufficient storage. Do not erase a simulator containing data you need.
4. If automatic recovery also fails, open Device Hub/Simulator from Xcode and inspect the runtime error. Restart Xcode or the Mac if the host service remains unhealthy, then rerun setup and validation. The scripts leave host-wide service restarts to the user because they interrupt other sessions.

## What validation proves

`validate.sh` must report a successful build and successful tests. `validate-ui.sh` proves that the app can build, install, launch its requested route and capture a screenshot. Inspect that screenshot separately. Dynamic Type screenshots do not establish VoiceOver navigation or Reduce Motion behavior; check those interactively in the simulator's accessibility settings when relevant to the UI change.

Simulator discovery/recovery regression tests also run without Xcode:

```sh
python3 -m unittest discover -s scripts/tests -v
```
