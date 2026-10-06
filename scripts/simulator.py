"""Select/create and boot an iOS simulator. Stdout contains only its UUID."""
import argparse
import json
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

from simulator_lease import LeaseTimeout, SimulatorLease


class SetupError(Exception):
    pass


PERMISSION_HELP = (
    "Simulator access is blocked by host/agent permissions or an unavailable CoreSimulator service. Retry the same script "
    "with host execution permitted, or run it in macOS Terminal. "
    "See docs/simulator-validation.md for step-by-step setup."
)


def simctl(args, timeout=30, lease=None):
    try:
        result = subprocess.run(["xcrun", "simctl", *args], capture_output=True,
                                text=True, timeout=timeout,
                                pass_fds=(lease.file.fileno(),) if lease else ())
    except subprocess.TimeoutExpired as error:
        raise SetupError("simctl " + " ".join(args) + " timed out") from error
    if result.returncode:
        detail = (result.stderr + result.stdout).strip()
        if any(message in detail.lower() for message in
               ("operation not permitted", "permission denied", "connection invalid", "service connection")):
            raise SetupError(PERMISSION_HELP + "\n" + detail)
        raise SetupError("simctl " + " ".join(args) + ": " + detail)
    if "-j" in args:
        try:
            return json.loads(result.stdout)
        except ValueError as error:
            raise SetupError("simctl returned invalid JSON") from error
    return result.stdout.strip()


def version(value):
    return tuple(int(part) for part in value.split("."))


def prepare(family, udid, minimum, boot_timeout, lease=None):
    runtimes = [r for r in simctl(["list", "runtimes", "-j"])["runtimes"]
                if r.get("isAvailable") and r.get("name", "").startswith("iOS ")
                and version(r["version"]) >= version(str(minimum))]
    runtimes.sort(key=lambda r: version(r["version"]), reverse=True)
    if not runtimes:
        raise SetupError(
            "No available iOS simulator runtime meets the deployment target.\n"
            "1. Open Xcode > Settings > Components and install an iOS runtime,\n"
            "   or run: xcodebuild -downloadPlatform iOS\n"
            "2. Run ./scripts/setup-simulator.sh again."
        )
    device_types = simctl(["list", "devicetypes", "-j"])["devicetypes"]
    family_name = {"iphone": "iPhone", "ipad": "iPad"}[family]
    types = {d["identifier"]: d for d in device_types
             if d.get("productFamily") == family_name and d["name"].startswith(family_name)}
    devices = simctl(["list", "devices", "available", "-j"])["devices"]
    candidates = []
    for runtime in runtimes:
        compatible = [d for d in devices.get(runtime["identifier"], [])
                      if d.get("isAvailable") and d.get("deviceTypeIdentifier") in types]
        compatible.sort(key=lambda d: (d.get("state") != "Booted", not d["name"].startswith("OneSet Validation"), d["name"], d["udid"]))
        candidates.extend(compatible)
    if udid:
        candidates = [d for d in candidates if d["udid"] == udid]
        if not candidates:
            raise SetupError("ONESET_SIMULATOR_UDID is unavailable or incompatible with the selected family/runtime: " + udid)
    # Bound recovery time; never reset or erase a user's simulator.
    for device in candidates[:2]:
        print("==> Waiting for " + device["name"] + " (" + device["udid"] + ")", file=sys.stderr)
        if lease:
            lease.acquire(device["udid"])
        try:
            simctl(["bootstatus", device["udid"], "-b"], timeout=boot_timeout, lease=lease)
            return device["udid"]
        except SetupError as error:
            if lease:
                lease.close()
            if udid or PERMISSION_HELP in str(error):
                raise
            print("==> Boot failed; trying another simulator: " + str(error), file=sys.stderr)
    for runtime in runtimes:
        supported = runtime.get("supportedDeviceTypes", [])
        # Modern simctl advertises the exact runtime/device compatibility matrix.
        compatible = [d for d in supported if d["identifier"] in types]
        if not supported:
            compatible = [d for d in types.values()
                          if version(d.get("minRuntimeVersionString", "0")) <= version(runtime["version"])
                          <= version(d.get("maxRuntimeVersionString", "65535"))]
        for device_type in compatible[:2]:
            try:
                name = "OneSet Validation " + family_name + " " + runtime["version"]
                created = simctl(["create", name, device_type["identifier"], runtime["identifier"]])
                print("==> Created " + name + " (" + created + ")", file=sys.stderr)
                if lease:
                    lease.acquire(created)
                simctl(["bootstatus", created, "-b"], timeout=boot_timeout, lease=lease)
                return created
            except SetupError as error:
                if lease:
                    lease.close()
                if PERMISSION_HELP in str(error):
                    raise
                print("==> Creation/boot failed: " + str(error), file=sys.stderr)
    raise SetupError("Could not boot a compatible simulator. See docs/simulator-validation.md; existing devices were preserved.")


def deployment_target():
    project = Path(__file__).resolve().parents[1] / "OneSet.xcodeproj/project.pbxproj"
    targets = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([0-9.]+);", project.read_text())
    if not targets:
        raise SetupError("Cannot determine IPHONEOS_DEPLOYMENT_TARGET from the project")
    return max(targets, key=version)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--family", choices=("iphone", "ipad"), default="iphone")
    parser.add_argument("--udid")
    parser.add_argument("--boot-timeout", type=int, default=180)
    parser.add_argument("--lock-timeout", type=float, default=os.environ.get("ONESET_SIMULATOR_LOCK_TIMEOUT", "900"))
    parser.add_argument("--run", nargs=argparse.REMAINDER, help="Command to run while holding the simulator lease")
    args = parser.parse_args()
    if args.boot_timeout <= 0:
        parser.error("--boot-timeout must be positive")
    if not 0 < args.lock_timeout < float("inf"):
        parser.error("--lock-timeout must be positive and finite")
    if args.run == []:
        parser.error("--run requires a command")
    lease = SimulatorLease(args.lock_timeout, args.run or ())
    # Raising during subprocess.run terminates and reaps its child before releasing
    # the lease. During the workflow, lease.run instead forwards signals for cleanup.
    def interrupted(signum, frame):
        raise SystemExit(128 + signum)

    previous = {signum: signal.signal(signum, interrupted)
                for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)}
    try:
        udid = prepare(args.family, args.udid, deployment_target(), args.boot_timeout, lease)
        if args.run:
            return lease.run(args.run, udid)
        print(udid)
    except (SetupError, LeaseTimeout, OSError, ValueError, KeyError) as error:
        print("Simulator setup failed: " + str(error), file=sys.stderr)
        return 1
    finally:
        lease.close()
        for signum, handler in previous.items():
            signal.signal(signum, handler)
    return 0


if __name__ == "__main__":
    sys.exit(main())
