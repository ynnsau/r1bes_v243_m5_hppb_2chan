from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "check_quartus_ip.py"
SPEC = importlib.util.spec_from_file_location("check_quartus_ip", SCRIPT)
assert SPEC and SPEC.loader
check_quartus_ip = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = check_quartus_ip
SPEC.loader.exec_module(check_quartus_ip)


class CollateralTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.project = Path(self.tempdir.name)
        (self.project / "demo.qsf").write_text(
            "set_global_assignment -name IP_FILE ip/fifo.ip\n", encoding="utf-8"
        )
        (self.project / "ip").mkdir()
        (self.project / "ip/fifo.ip").write_text("descriptor\n", encoding="utf-8")

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def test_missing_generated_qip_reports_descriptor_as_generation_input(self) -> None:
        result = check_quartus_ip.inspect(self.project, "demo")
        self.assertEqual(result.status, "incomplete")
        self.assertEqual(result.missing_qips, ["ip/fifo/fifo.qip"])
        self.assertEqual(result.generation_inputs, ["ip/fifo.ip"])

    def test_qip_referenced_synthesis_file_must_exist(self) -> None:
        generated = self.project / "ip/fifo"
        generated.mkdir()
        qip = generated / "fifo.qip"
        qip.write_text(
            'set_global_assignment -name VERILOG_FILE '
            '[file join $::quartus(qip_path) "synth/fifo.v"]\n',
            encoding="utf-8",
        )
        missing = check_quartus_ip.inspect(self.project, "demo")
        self.assertEqual(missing.status, "incomplete")
        self.assertEqual(missing.missing_qip_references, ["ip/fifo/synth/fifo.v"])

        (generated / "synth").mkdir()
        (generated / "synth/fifo.v").write_text("module fifo; endmodule\n")
        ready = check_quartus_ip.inspect(self.project, "demo")
        self.assertEqual(ready.status, "ready")

    def test_generation_command_is_explicit_and_project_scoped(self) -> None:
        result = check_quartus_ip.inspect(self.project, "demo")
        command = check_quartus_ip.generation_command(result, "demo_rev")
        assert command is not None
        self.assertEqual(command[:2], ["qsys-generate", "ip/fifo.ip"])
        self.assertIn("--quartus-project=demo.qpf", command)
        self.assertIn("--rev=demo_rev", command)


if __name__ == "__main__":
    unittest.main()
