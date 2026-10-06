"""Host-wide simulator leases and protected command execution (macOS/POSIX)."""
import fcntl
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


class LeaseTimeout(Exception):
    pass


class SimulatorLease:
    def __init__(self, timeout, command=(), directory=None):
        self.timeout = timeout
        self.command = command
        self.directory = Path(directory) if directory else Path.home() / "Library/Caches/OneSet/simulator-locks"
        self.file = None

    def acquire(self, udid):
        self.close()
        # simctl supplies UUIDs; reject path components even for direct callers.
        if not udid or any(c not in "0123456789abcdefABCDEF-" for c in udid):
            raise ValueError("Invalid simulator UUID: " + udid)
        self.directory.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.file = (self.directory / (udid.lower() + ".lock")).open("a+")
        started = time.monotonic()
        next_report = 0
        while True:
            try:
                fcntl.flock(self.file, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                elapsed = time.monotonic() - started
                if elapsed >= self.timeout:
                    self.close()
                    raise LeaseTimeout(f"Timed out after {self.timeout:g}s waiting for simulator {udid}")
                if elapsed >= next_report:
                    self.file.seek(0)
                    holder = self.file.read().strip() or "holder details pending"
                    print(f"==> Simulator {udid} busy ({elapsed:.0f}s elapsed): {holder}", file=sys.stderr)
                    next_report = elapsed + 10
                time.sleep(min(0.1, self.timeout - elapsed))
        self.file.seek(0)
        self.file.truncate()
        json.dump({"pid": os.getpid(), "command": list(self.command) or sys.argv,
                   "worktree": os.getcwd()}, self.file)
        self.file.flush()

    def close(self):
        # Do not unlock explicitly: a protected child may still hold this descriptor.
        if self.file is not None:
            self.file.close()
            self.file = None

    def run(self, command, udid):
        env = dict(os.environ, SIMULATOR_UDID=udid)
        previous = {}
        child = None
        pending = []
        queued = []

        def forward(signum, frame):
            pending.append(signum)
            if child is None:
                queued.append(signum)
            else:
                try:
                    os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass

        try:
            for signum in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
                previous[signum] = signal.signal(signum, forward)
            child = subprocess.Popen(command, env=env, start_new_session=True,
                                     pass_fds=(self.file.fileno(),))
            for signum in queued:
                try:
                    os.killpg(child.pid, signum)
                except ProcessLookupError:
                    pass
            status = child.wait()
            return 128 + pending[0] if pending else (128 - status if status < 0 else status)
        finally:
            for signum, handler in previous.items():
                signal.signal(signum, handler)
