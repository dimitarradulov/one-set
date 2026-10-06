"""Regression coverage for simulator discovery and recovery; no Xcode required."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import Mock, patch


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

spec = importlib.util.spec_from_file_location(
    "simulator", Path(__file__).resolve().parents[1] / "simulator.py"
)
simulator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(simulator)


def runtime(version="27.0", available=True):
    return {
        "identifier": "ios-" + version, "name": "iOS " + version,
        "version": version, "isAvailable": available,
        "supportedDeviceTypes": [
            {"identifier": "phone", "name": "iPhone Available", "productFamily": "iPhone"},
            {"identifier": "pad", "name": "iPad Available", "productFamily": "iPad"},
        ],
    }


def device(udid="existing", family="phone", state="Shutdown"):
    return {"udid": udid, "name": "Some device", "deviceTypeIdentifier": family,
            "state": state, "isAvailable": True}


class SimulatorTests(unittest.TestCase):
    def prepare(self, devices, runtimes=None, family="iphone", udid=None, fail_boot=False, lease=None):
        calls = []

        def run(args, timeout=30, lease=None):
            calls.append(args)
            if args == ["list", "runtimes", "-j"]:
                return {"runtimes": runtimes if runtimes is not None else [runtime()]}
            if args == ["list", "devices", "available", "-j"]:
                return {"devices": devices}
            if args == ["list", "devicetypes", "-j"]:
                return {"devicetypes": runtime()["supportedDeviceTypes"]}
            if args[0] == "create":
                return "replacement"
            if args[0] == "bootstatus" and fail_boot and args[1] != "replacement":
                raise simulator.SetupError("boot timed out")
            return ""

        with patch.object(simulator, "simctl", side_effect=run):
            result = simulator.prepare(family, udid, 17, 2, lease)
        return result, calls

    def test_failed_boot_releases_before_leasing_replacement(self):
        lease = Mock()
        self.prepare({"ios-27.0": [device()]}, fail_boot=True, lease=lease)
        self.assertEqual([call[0] for call in lease.method_calls], ["acquire", "close", "acquire"])

    def test_lock_timeout_prevents_boot_and_recovery(self):
        lease = Mock()
        lease.acquire.side_effect = simulator.LeaseTimeout("busy")
        with self.assertRaises(simulator.LeaseTimeout):
            self.prepare({"ios-27.0": [device()]}, lease=lease)
        lease.acquire.assert_called_once_with("existing")
        lease.close.assert_not_called()

    def test_missing_hard_coded_phone_uses_available_device(self):
        result, calls = self.prepare({"ios-27.0": [device()]})
        self.assertEqual(result, "existing")
        self.assertIn(["bootstatus", "existing", "-b"], calls)

    def test_empty_device_list_creates_compatible_phone(self):
        result, calls = self.prepare({})
        self.assertEqual(result, "replacement")
        self.assertTrue(any(c[0] == "create" and c[2:] == ["phone", "ios-27.0"] for c in calls))

    def test_ipad_selection_never_uses_booted_phone(self):
        result, _ = self.prepare({"ios-27.0": [device(state="Booted"), device("ipad", "pad")]}, family="ipad")
        self.assertEqual(result, "ipad")

    def test_broken_device_recovers_without_erasing_it(self):
        result, calls = self.prepare({"ios-27.0": [device()]}, fail_boot=True)
        self.assertEqual(result, "replacement")
        self.assertFalse(any(c[0] in ("erase", "delete", "shutdown") for c in calls))

    def test_missing_explicit_udid_fails_instead_of_switching_devices(self):
        with self.assertRaisesRegex(simulator.SetupError, "ONESET_SIMULATOR_UDID"):
            self.prepare({"ios-27.0": [device()]}, udid="missing")

    def test_explicit_device_boot_failure_does_not_switch_devices(self):
        with self.assertRaisesRegex(simulator.SetupError, "boot timed out"):
            self.prepare({"ios-27.0": [device()]}, udid="existing", fail_boot=True)

    def test_missing_runtime_has_installation_steps(self):
        with self.assertRaisesRegex(simulator.SetupError, "downloadPlatform iOS"):
            self.prepare({}, runtimes=[])

    def test_unavailable_or_older_runtime_is_not_selected(self):
        result, _ = self.prepare({"ios-16.0": [device("old")], "ios-27.0": [device()]},
                                 runtimes=[runtime("16.0"), runtime("28.0", False), runtime()])
        self.assertEqual(result, "existing")

    def test_boot_subprocess_inherits_lease_descriptor(self):
        lease = Mock()
        lease.file.fileno.return_value = 42
        with patch.object(simulator.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as run:
            simulator.simctl(["bootstatus", "uuid", "-b"], lease=lease)
        self.assertEqual(run.call_args.kwargs["pass_fds"], (42,))

    def test_simctl_timeout_is_actionable(self):
        with patch.object(simulator.subprocess, "run", side_effect=subprocess.TimeoutExpired("simctl", 1)):
            with self.assertRaisesRegex(simulator.SetupError, "timed out"):
                simulator.simctl(["list", "runtimes", "-j"], timeout=1)

    def test_permission_error_is_not_treated_as_missing_runtime(self):
        denied = subprocess.CompletedProcess([], 1, "", "Operation not permitted")
        with patch.object(simulator.subprocess, "run", return_value=denied):
            with self.assertRaisesRegex(simulator.SetupError, "permission"):
                simulator.simctl(["list", "runtimes", "-j"])


if __name__ == "__main__":
    unittest.main()
