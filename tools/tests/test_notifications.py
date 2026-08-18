from __future__ import annotations

import contextlib
import importlib.util
import io
import os
import subprocess
import unittest
from pathlib import Path
from unittest import mock


TOOLS = Path(__file__).resolve().parents[1]
SCRIPT = TOOLS / "send_workflow_ping.py"
SPEC = importlib.util.spec_from_file_location("send_workflow_ping", SCRIPT)
assert SPEC and SPEC.loader
send_workflow_ping = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(send_workflow_ping)


class NotificationTests(unittest.TestCase):
    def test_pushover_dry_run_redacts_credentials(self) -> None:
        output = io.StringIO()
        with mock.patch.dict(
            os.environ,
            {
                "PUSHOVER_APP_TOKEN": "secret-token",
                "PUSHOVER_USER_KEY": "secret-user",
                "WORKFLOW_PING_TRANSPORT": "pushover",
            },
            clear=False,
        ), contextlib.redirect_stdout(output):
            rc = send_workflow_ping.main(
                [
                    "--event",
                    "regression-finish",
                    "--name",
                    "unit test",
                    "--status",
                    "PASS",
                    "--body",
                    "done",
                    "--dry-run",
                ]
            )
        rendered = output.getvalue()
        self.assertEqual(rc, 0)
        self.assertIn("<redacted>", rendered)
        self.assertNotIn("secret-token", rendered)
        self.assertNotIn("secret-user", rendered)

    def test_wrapper_preserves_command_status_when_pings_disabled(self) -> None:
        proc = subprocess.run(
            [
                "bash",
                str(TOOLS / "workflow_notify_run.sh"),
                "--kind",
                "command",
                "--name",
                "status test",
                "--",
                "bash",
                "-c",
                "exit 7",
            ],
            env={**os.environ, "WORKFLOW_NOTIFY": "0"},
            check=False,
        )
        self.assertEqual(proc.returncode, 7)


if __name__ == "__main__":
    unittest.main()
