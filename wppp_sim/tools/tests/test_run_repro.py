from __future__ import annotations

import contextlib
import importlib.util
import io
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS = Path(__file__).resolve().parents[1]
SCRIPT = TOOLS / "run_repro.py"
SPEC = importlib.util.spec_from_file_location("run_repro", SCRIPT)
assert SPEC and SPEC.loader
run_repro = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = run_repro
SPEC.loader.exec_module(run_repro)


class ReproRunnerTests(unittest.TestCase):
    def test_parse_spec_keeps_marker_text(self) -> None:
        spec = run_repro.parse_spec("RUN_BUG::WPPP_REPRODUCED: exact marker")
        self.assertEqual(spec.name, "RUN_BUG")
        self.assertEqual(spec.marker, "WPPP_REPRODUCED: exact marker")

    def test_dry_run_is_read_only(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            log_dir = Path(raw) / "logs"
            with contextlib.redirect_stdout(io.StringIO()):
                rc = run_repro.main(
                    [
                        "--log-dir",
                        str(log_dir),
                        "--dry-run",
                        "RUN_BUG::marker",
                    ]
                )
            self.assertEqual(rc, 0)
            self.assertFalse(log_dir.exists())


if __name__ == "__main__":
    unittest.main()
