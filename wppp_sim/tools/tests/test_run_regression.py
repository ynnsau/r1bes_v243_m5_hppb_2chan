from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


TOOLS = Path(__file__).resolve().parents[1]
SCRIPT = TOOLS / "run_regression.py"
SPEC = importlib.util.spec_from_file_location("run_regression", SCRIPT)
assert SPEC and SPEC.loader
run_regression = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = run_regression
SPEC.loader.exec_module(run_regression)


class RegressionRunnerTests(unittest.TestCase):
    def test_schedule_uses_history_and_longest_first(self) -> None:
        schedule = run_regression.make_schedule(
            ["RUN_SHORT", "RUN_LONG"],
            "full",
            {"RUN_SHORT": 1.0, "RUN_LONG": 9.0},
            ["+SEED=4"],
        )
        self.assertEqual([spec.name for spec in schedule], ["RUN_LONG", "RUN_SHORT"])
        self.assertEqual(schedule[0].plusargs, ["+RUN_LONG", "+SEED=4"])

    def test_classification_requires_clean_exit_and_completion_marker(self) -> None:
        self.assertEqual(
            run_regression.classify("RUN_ONE", 0, "WPPP_TEST_PASS: RUN_ONE\n")[0],
            "PASS",
        )
        self.assertEqual(run_regression.classify("RUN_ONE", 0, "Errors: 1\n")[0], "FAIL")
        self.assertEqual(
            run_regression.classify(
                "RUN_ONE", 0, "WPPP_INT_CHECK_ERROR: bad AXI response\n"
            )[0],
            "FAIL",
        )
        self.assertEqual(run_regression.classify("RUN_ONE", 1, "WPPP_TEST_PASS: RUN_ONE\n")[0], "FAIL")

    def test_pass_without_rerun_has_empty_verbose_paths(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            transcript = root / "run.vsim.log"
            make_log = root / "run.make.log"
            transcript.write_text("WPPP_TEST_PASS: RUN_ONE\n", encoding="utf-8")
            make_log.write_text("ok\n", encoding="utf-8")
            spec = run_regression.TestSpec("RUN_ONE", ["+RUN_ONE"], 1.0)
            with mock.patch.object(
                run_regression,
                "run_make",
                return_value=(0, 0.1, make_log, transcript),
            ):
                result = run_regression.run_test(
                    spec, root, root, ["make"], False, True, False
                )
            self.assertEqual(result.status, "PASS")
            self.assertEqual(result.verbose_make_log, "")
            self.assertEqual(result.verbose_vsim_log, "")

    def test_dry_run_does_not_create_log_directory(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / "Makefile").write_text("all:\n\t@true\n", encoding="utf-8")
            log_dir = root / "logs"
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = run_regression.main(
                    [
                        "--profile",
                        "smoke",
                        "--cwd",
                        str(root),
                        "--log-dir",
                        str(log_dir),
                        "--dry-run",
                        "RUN_ONE",
                    ]
                )
            self.assertEqual(rc, 0)
            self.assertFalse(log_dir.exists())
            self.assertEqual(json.loads(output.getvalue())["profile"], "smoke")


if __name__ == "__main__":
    unittest.main()
