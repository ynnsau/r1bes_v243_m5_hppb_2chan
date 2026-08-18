from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "run_quartus.py"
SPEC = importlib.util.spec_from_file_location("run_quartus", SCRIPT)
assert SPEC and SPEC.loader
run_quartus = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = run_quartus
SPEC.loader.exec_module(run_quartus)


class QuartusParserTests(unittest.TestCase):
    def test_flow_and_worst_matching_setup_timing(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            flow = root / "flow.rpt"
            sta = root / "sta.summary"
            flow.write_text(
                "; Flow Status ; Successful - Tue Aug 18 2026 ;\n", encoding="utf-8"
            )
            sta.write_text(
                """Type  : Setup 'unrelated_clock'
Slack : -9.999
TNS   : -1.000

Type  : Setup 'path.coreclkout_hip'
Slack : -0.775
TNS   : -100.000

Type  : Setup 'another.coreclkout_hip'
Slack : -0.810
TNS   : -120.000
""",
                encoding="utf-8",
            )
            self.assertEqual(run_quartus.parse_flow_status(flow), "Successful - Tue Aug 18 2026")
            self.assertEqual(
                run_quartus.parse_setup_timing(sta, "coreclkout_hip"),
                (-0.810, -120.000),
            )

    def test_error_scan_does_not_reject_zero_error_summary(self) -> None:
        self.assertFalse(run_quartus.contains_quartus_error("Errors: 0, Warnings: 4"))
        self.assertTrue(run_quartus.contains_quartus_error("Error (12345): bad RTL"))
        self.assertTrue(run_quartus.contains_quartus_error("Errors: 2"))


class QuartusRunnerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        self.project_dir = self.root / "hardware_test_design"
        self.project_dir.mkdir()
        (self.project_dir / "cxltyp2_ed.qpf").write_text("PROJECT_REVISION = cxltyp2_ed\n")
        (self.project_dir / "cxltyp2_ed.qsf").write_text("# test\n")

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def fake_tool(self, wns: float = -0.800) -> Path:
        tool = self.root / "fake_quartus.py"
        tool.write_text(
            f"""#!/usr/bin/env python3
import sys
from pathlib import Path
if '--version' in sys.argv:
    print('Fake Quartus')
    print('Version 25.3.0 Test')
    raise SystemExit(0)
out = Path('output_files')
out.mkdir(exist_ok=True)
if '--quick_elab' in sys.argv:
    (out / 'cxltyp2_ed.syn.quick_elab.rpt').write_text('Analysis successful. Errors: 0\\n')
else:
    (out / 'cxltyp2_ed.flow.rpt').write_text('; Flow Status ; Successful - now ;\\n')
    (out / 'cxltyp2_ed.sta.summary').write_text("Type  : Setup 'path.coreclkout_hip'\\nSlack : {wns:.3f}\\nTNS   : -10.000\\n")
print('Errors: 0')
""",
            encoding="utf-8",
        )
        tool.chmod(0o755)
        return tool

    def test_dry_run_is_read_only(self) -> None:
        log_dir = self.root / "never-created"
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            rc = run_quartus.main(
                [
                    "--mode",
                    "quick-elab",
                    "--project-dir",
                    str(self.project_dir),
                    "--log-dir",
                    str(log_dir),
                    "--quartus-syn",
                    "/bin/true",
                    "--dry-run",
                ]
            )
        self.assertEqual(rc, 0)
        self.assertFalse(log_dir.exists())
        self.assertEqual(json.loads(output.getvalue())["mode"], "quick-elab")

    def test_fake_full_compile_passes_with_fresh_reports(self) -> None:
        log_dir = self.root / "passing"
        rc = run_quartus.main(
            [
                "--mode",
                "full",
                "--project-dir",
                str(self.project_dir),
                "--log-dir",
                str(log_dir),
                "--quartus-sh",
                str(self.fake_tool(-0.800)),
            ]
        )
        self.assertEqual(rc, 0)
        result = json.loads((log_dir / "result.json").read_text())
        self.assertEqual(result["status"], "pass")
        self.assertEqual(result["setup_wns_ns"], -0.8)

    def test_fake_full_compile_enforces_timing_gate(self) -> None:
        log_dir = self.root / "timing-fail"
        rc = run_quartus.main(
            [
                "--mode",
                "full",
                "--project-dir",
                str(self.project_dir),
                "--log-dir",
                str(log_dir),
                "--quartus-sh",
                str(self.fake_tool(-0.901)),
            ]
        )
        self.assertEqual(rc, 1)
        result = json.loads((log_dir / "result.json").read_text())
        self.assertEqual(result["status"], "timing_fail")


if __name__ == "__main__":
    unittest.main()
