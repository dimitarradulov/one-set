"""Exercise shell entry points and failure reporting with fake host commands."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class ValidationCommandsTests(unittest.TestCase):
    def shell(self, code, directory, fake_command=None):
        environment = os.environ.copy()
        environment["ONESET_TEST_COMMON"] = str(ROOT / "scripts/validation-common.sh")
        environment["ONESET_ARTIFACTS_DIR"] = str(directory / "artifacts")
        environment["ONESET_TEST_LOG"] = str(directory / "build.log")
        environment["ONESET_TEST_CAPTURE"] = str(directory / "xcodebuild-args")
        if fake_command:
            name, body = fake_command
            executable = directory / name
            executable.write_text("#!/bin/bash\n" + body + "\n")
            executable.chmod(0o755)
            environment["PATH"] = str(directory) + os.pathsep + environment["PATH"]
        return subprocess.run(["bash", "-c", 'set -euo pipefail; source "$ONESET_TEST_COMMON"; ' + code],
                              env=environment, cwd=directory, capture_output=True, text=True, timeout=10)

    def test_xcode_failure_preserves_status_log_and_recovery_steps(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            result = self.shell('oneset_xcodebuild "$ONESET_TEST_LOG" build', directory,
                                ("xcodebuild", 'echo "sandbox_apply: Operation not permitted"; exit 65'))
            self.assertEqual(result.returncode, 65)
            self.assertIn("host execution", result.stderr)
            self.assertIn("Operation not permitted", (directory / "build.log").read_text())

    def test_xcodebuild_uses_only_the_active_architecture(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            result = self.shell('oneset_xcodebuild "$ONESET_TEST_LOG" -project OneSet.xcodeproj build', directory,
                                ("xcodebuild", 'printf "%s\\n" "$@" > "$ONESET_TEST_CAPTURE"'))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("ONLY_ACTIVE_ARCH=YES", (directory / "xcodebuild-args").read_text().splitlines())

    def test_artifact_write_denial_is_caught_even_when_directory_exists(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            (directory / "artifacts").mkdir()
            result = self.shell('oneset_artifacts', directory, ("mktemp", "exit 1"))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("ONESET_ARTIFACTS_DIR=/tmp/oneset-validation", result.stderr)

    def test_artifact_override_works_outside_repository(self):
        with tempfile.TemporaryDirectory() as path:
            directory = Path(path)
            result = self.shell('oneset_artifacts; echo "$ONESET_ARTIFACTS_DIR"', directory)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(Path(result.stdout.strip()).resolve(), (directory / "artifacts").resolve())
            self.assertEqual(list((directory / "artifacts").iterdir()), [])

    def test_unknown_preview_route_fails_before_xcode(self):
        result = subprocess.run(["bash", str(ROOT / "scripts/validate-ui.sh"), "--ui-missing-route"],
                                cwd="/tmp", capture_output=True, text=True, timeout=10)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("existing route", result.stderr)
        self.assertNotIn("==> Xcode", result.stderr)


if __name__ == "__main__":
    unittest.main()
