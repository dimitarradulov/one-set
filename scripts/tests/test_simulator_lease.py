"""Real-process coverage of simulator isolation; no Xcode required."""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from simulator_lease import LeaseTimeout, SimulatorLease

SCRIPTS = Path(__file__).resolve().parents[1]
UUID = "abcdefab-1111-1111-1111-111111111111"
OTHER_UUID = "22222222-2222-2222-2222-222222222222"
HARNESS = '''
import sys
from simulator_lease import SimulatorLease
lease = SimulatorLease(float(sys.argv[3]), sys.argv[4:], sys.argv[1])
try:
    lease.acquire(sys.argv[2])
    sys.exit(lease.run(sys.argv[4:], sys.argv[2]))
finally:
    lease.close()
'''


class LeaseTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.locks = self.root / "locks"
        self.processes = []
        self.addCleanup(self.stop_processes)

    def stop_processes(self):
        for process in self.processes:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
            process.communicate(timeout=3)

    def wait_for(self, path):
        deadline = time.monotonic() + 5
        while not path.exists():
            if time.monotonic() > deadline:
                self.fail("Timed out waiting for " + str(path))
            time.sleep(0.01)

    def start(self, command, udid=UUID, timeout=3, worktree="first", harness=HARNESS):
        directory = self.root / worktree
        directory.mkdir(exist_ok=True)
        env = dict(os.environ, PYTHONPATH=str(SCRIPTS), ONESET_ARTIFACTS_DIR=str(directory / "artifacts"))
        process = subprocess.Popen([sys.executable, "-c", harness, str(self.locks), udid,
                                    str(timeout), *command], cwd=directory, env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.processes.append(process)
        return process

    def holder(self):
        ready, gate = self.root / "ready", self.root / "gate"
        code = ('import pathlib,time,os; '
                f'pathlib.Path({str(ready)!r}).write_text(str(os.getpid())); '
                f'gate=pathlib.Path({str(gate)!r}); '
                '\nwhile not gate.exists(): time.sleep(0.01)')
        process = self.start([sys.executable, "-c", code])
        self.wait_for(ready)
        return process, ready, gate

    def probe(self, udid=UUID, timeout=0.1):
        lease = SimulatorLease(timeout, directory=self.locks)
        self.addCleanup(lease.close)
        lease.acquire(udid)
        return lease

    def test_same_uuid_serializes_across_worktrees_and_artifact_roots(self):
        first, _, gate = self.holder()
        captured = self.root / "captured"
        second = self.start([sys.executable, "-c", f'from pathlib import Path; Path({str(captured)!r}).touch()'],
                            udid=UUID.upper(), worktree="second")
        time.sleep(0.2)
        self.assertFalse(captured.exists())
        gate.touch()
        self.assertEqual(first.wait(timeout=3), 0)
        self.assertEqual(second.wait(timeout=3), 0)
        self.assertTrue(captured.exists())
        _, diagnostics = second.communicate()
        self.assertIn("busy", diagnostics)
        self.assertIn("worktree", diagnostics)

    def test_distinct_devices_can_run_concurrently(self):
        first, _, _ = self.holder()
        second = self.start([sys.executable, "-c", 'pass'], udid=OTHER_UUID, worktree="second")
        self.assertEqual(second.wait(timeout=3), 0)
        self.assertIsNone(first.poll())

    def test_timeout_does_not_run_protected_command(self):
        self.holder()
        captured = self.root / "unexpected"
        second = self.start([sys.executable, "-c", f'from pathlib import Path; Path({str(captured)!r}).touch()'], timeout=0.1)
        self.assertNotEqual(second.wait(timeout=3), 0)
        self.assertFalse(captured.exists())
        self.assertIn("Timed out", second.communicate()[1])

    def test_success_and_failure_release_lock_and_preserve_exit_status(self):
        for status in (0, 7):
            process = self.start([sys.executable, "-c", f'import sys; sys.exit({status})'])
            self.assertEqual(process.wait(timeout=3), status)
            self.probe().close()

    def test_interruption_waits_for_shell_cleanup_before_release(self):
        ready, cleanup = self.root / "ready", self.root / "cleanup"
        command = ['bash', '-c', 'trap \'sleep 0.2; touch "$2"\' EXIT; '
                   'trap "exit 143" TERM; touch "$1"; while true; do sleep 0.1; done',
                   'protected', str(ready), str(cleanup)]
        process = self.start(command)
        self.wait_for(ready)
        process.terminate()
        with self.assertRaises(LeaseTimeout):
            self.probe(timeout=0.05)
        self.assertEqual(process.wait(timeout=3), 143)
        self.assertTrue(cleanup.exists())
        self.probe().close()

    def test_killed_supervisor_keeps_child_reserved(self):
        process, _, gate = self.holder()
        process.kill()
        process.wait(timeout=3)
        with self.assertRaises(LeaseTimeout):
            self.probe()
        gate.touch()
        self.probe(timeout=3).close()

    def test_sigint_is_forwarded_and_exit_status_preserved(self):
        ready = self.root / "ready"
        process = self.start(['bash', '-c', 'trap "exit 130" INT; touch "$1"; '
                              'while true; do sleep 0.1; done', 'protected', str(ready)])
        self.wait_for(ready)
        process.send_signal(signal.SIGINT)
        self.assertEqual(process.wait(timeout=3), 130)
        self.probe().close()

    def test_interruption_during_boot_reaps_simctl_before_release(self):
        ready = self.root / "ready"
        fake = self.root / "xcrun"
        fake.write_text(f"#!{sys.executable}\nfrom pathlib import Path\nimport time\n"
                        f"Path({str(ready)!r}).touch()\ntime.sleep(30)\n")
        fake.chmod(0o755)
        harness = f'''
import os, sys
import simulator
from simulator_lease import SimulatorLease
os.environ["PATH"] = {str(self.root)!r} + os.pathsep + os.environ["PATH"]
locks, udid = sys.argv[1:3]
simulator.SimulatorLease = lambda timeout, command: SimulatorLease(timeout, command, locks)
def prepare(family, requested, minimum, timeout, lease):
    lease.acquire(udid)
    simulator.simctl(["bootstatus", udid, "-b"], timeout=30, lease=lease)
    return udid
simulator.prepare = prepare
sys.argv = ["simulator"]
sys.exit(simulator.main())
'''
        process = self.start([], harness=harness)
        self.wait_for(ready)
        process.terminate()
        self.assertEqual(process.wait(timeout=3), 143)
        self.probe().close()

    def test_invalid_timeout_fails_before_simulator_access(self):
        for timeout in ("0", "-1", "nan", "inf", "invalid"):
            env = dict(os.environ, ONESET_SIMULATOR_LOCK_TIMEOUT=timeout)
            result = subprocess.run([sys.executable, str(SCRIPTS / "simulator.py")],
                                    env=env, capture_output=True, text=True, timeout=3)
            self.assertEqual(result.returncode, 2)
            self.assertIn("lock-timeout", result.stderr)
            self.assertNotIn("Waiting for", result.stderr)

    def test_lock_file_is_reused_and_metadata_is_not_a_lock(self):
        first = self.probe()
        path = self.locks / (UUID + ".lock")
        inode = path.stat().st_ino
        first.close()
        self.assertIn('"pid"', path.read_text())
        self.probe().close()
        self.assertEqual(path.stat().st_ino, inode)

    def test_unsafe_device_identifier_is_rejected(self):
        with self.assertRaises(ValueError):
            self.probe("../escape")

    def test_screenshot_helper_uses_held_lease_without_reacquiring(self):
        fake = self.root / "xcrun"
        fake.write_text('#!/bin/bash\ntouch "${@: -1}"\n')
        fake.chmod(0o755)
        output = self.root / "screenshots/preview.png"
        code = f'source "{SCRIPTS}/validation-common.sh"; export PATH="{self.root}:$PATH"; '
        code += f'ONESET_ARTIFACTS_DIR="{self.root}"; oneset_capture_screenshot preview'
        process = self.start(['bash', '-c', code])
        self.assertEqual(process.wait(timeout=3), 0, process.communicate()[1])
        self.assertTrue(output.exists())
