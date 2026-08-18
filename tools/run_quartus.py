#!/usr/bin/env python3
"""Run and classify the local cxltyp2_ed Quartus workflow.

Quick elaboration and full compilation have deliberately different evidence
requirements.  A quick run must create a fresh synthesis quick-elaboration
report.  A full run must create fresh flow and STA summaries and pass the
configured core-clock setup-WNS gate.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_PROJECT = "cxltyp2_ed"
DEFAULT_CLOCK = "coreclkout_hip"
DEFAULT_MIN_WNS = -0.900
FRESHNESS_TOLERANCE_SECONDS = 2.0
QUARTUS_ERROR_RE = re.compile(r"(?im)^\s*Error(?:\s+\(\d+\))?\s*:")
NONZERO_ERROR_SUMMARY_RE = re.compile(r"(?im)\bErrors:\s*[1-9][0-9]*\b")


class QuartusRunError(RuntimeError):
    """Raised for invalid workflow configuration, not design failure."""


@dataclass(frozen=True)
class FileStamp:
    exists: bool
    mtime_ns: int | None
    size: int | None


@dataclass
class CompileResult:
    schema_version: int
    mode: str
    status: str
    returncode: int
    started_at: str
    completed_at: str
    duration_seconds: float
    command: list[str]
    quartus_version: str
    project_dir: str
    project: str
    revision: str
    clock_name: str
    min_wns_ns: float | None
    setup_wns_ns: float | None
    setup_tns_ns: float | None
    flow_status: str | None
    reasons: list[str]
    log: str
    reports: dict[str, str]
    git_commit: str
    git_status_before: str
    git_status_after: str


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def read_text(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8", errors="replace")


def git_text(repo: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return proc.stdout.strip() if proc.returncode == 0 else "unknown"


def file_stamp(path: Path) -> FileStamp:
    try:
        stat = path.stat()
    except FileNotFoundError:
        return FileStamp(False, None, None)
    return FileStamp(True, stat.st_mtime_ns, stat.st_size)


def is_fresh(path: Path, before: FileStamp, started_epoch: float) -> bool:
    after = file_stamp(path)
    if not after.exists:
        return False
    changed = not before.exists or (
        before.mtime_ns != after.mtime_ns or before.size != after.size
    )
    assert after.mtime_ns is not None
    new_enough = after.mtime_ns / 1_000_000_000 >= (
        started_epoch - FRESHNESS_TOLERANCE_SECONDS
    )
    return changed and new_enough


def parse_flow_status(path: Path) -> str | None:
    for line in read_text(path).splitlines():
        if "Flow Status" not in line or ";" not in line:
            continue
        fields = [field.strip() for field in line.split(";")]
        if len(fields) >= 3 and fields[2]:
            return fields[2]
    return None


def parse_setup_timing(path: Path, clock_name: str) -> tuple[float | None, float | None]:
    """Return the worst matching setup slack and that block's TNS."""

    blocks: list[tuple[float, float | None]] = []
    matching = False
    slack: float | None = None
    tns: float | None = None

    def finish_block() -> None:
        if matching and slack is not None:
            blocks.append((slack, tns))

    for line in [*read_text(path).splitlines(), "Type : END '_sentinel_'"]:
        type_match = re.match(r"^Type\s+:\s+(\S+)\s+'([^']+)'", line)
        if type_match:
            finish_block()
            matching = type_match.group(1) == "Setup" and clock_name in type_match.group(2)
            slack = None
            tns = None
            continue
        if not matching:
            continue
        slack_match = re.match(r"^Slack\s+:\s+(-?\d+(?:\.\d+)?)", line)
        if slack_match:
            slack = float(slack_match.group(1))
            continue
        tns_match = re.match(r"^TNS\s+:\s+(-?\d+(?:\.\d+)?)", line)
        if tns_match:
            tns = float(tns_match.group(1))

    if not blocks:
        return None, None
    return min(blocks, key=lambda value: value[0])


def contains_quartus_error(*texts: str) -> bool:
    combined = "\n".join(texts)
    return bool(QUARTUS_ERROR_RE.search(combined) or NONZERO_ERROR_SUMMARY_RE.search(combined))


def command_for(args: argparse.Namespace) -> list[str]:
    if args.mode == "quick-elab":
        return [
            args.quartus_syn,
            "--read_settings_files=on",
            "--write_settings_files=off",
            args.project,
            "-c",
            args.revision,
            "--quick_elab",
        ]
    return [
        args.quartus_sh,
        "--flow",
        "compile",
        args.project,
        "-c",
        args.revision,
    ]


def report_paths(project_dir: Path, revision: str, mode: str) -> dict[str, Path]:
    output_dir = project_dir / "output_files"
    if mode == "quick-elab":
        return {"quick_elab": output_dir / f"{revision}.syn.quick_elab.rpt"}
    return {
        "flow": output_dir / f"{revision}.flow.rpt",
        "sta": output_dir / f"{revision}.sta.summary",
    }


def executable_path(name: str) -> str | None:
    if Path(name).is_file():
        return str(Path(name).resolve())
    return shutil.which(name)


def tool_version(command: str) -> str:
    proc = subprocess.run(
        [command, "--version"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    lines = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
    version_line = next((line for line in lines if line.startswith("Version ")), None)
    if version_line and lines:
        return f"{lines[0]} — {version_line}"
    return lines[0] if lines else "unknown"


def stream_command(command: list[str], cwd: Path, log_path: Path) -> int:
    with log_path.open("w", encoding="utf-8") as handle:
        handle.write("Command: " + shlex.join(command) + "\n")
        handle.flush()
        proc = subprocess.Popen(
            command,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        assert proc.stdout is not None
        try:
            with proc.stdout:
                for line in proc.stdout:
                    sys.stdout.write(line)
                    sys.stdout.flush()
                    handle.write(line)
        except KeyboardInterrupt:
            proc.terminate()
            proc.wait()
            raise
        return proc.wait()


def send_notification(
    tool: Path,
    event: str,
    priority: str,
    mode: str,
    status: str,
    log: Path,
    body: str,
) -> None:
    try:
        subprocess.run(
            [
                sys.executable,
                str(tool),
                "--event",
                event,
                "--priority",
                priority,
                "--name",
                f"cxltyp2_ed {mode}",
                "--status",
                status,
                "--log",
                str(log),
                "--body",
                body,
            ],
            check=False,
        )
    except OSError as exc:
        print(f"warning: notification helper could not run: {exc}", file=sys.stderr)


def find_repo_root(project_dir: Path) -> Path:
    output = git_text(project_dir, "rev-parse", "--show-toplevel")
    return Path(output).resolve() if output != "unknown" else project_dir.parent


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mode", choices=("quick-elab", "full"), required=True)
    parser.add_argument("--project-dir", type=Path, default=Path("hardware_test_design"))
    parser.add_argument("--project", default=DEFAULT_PROJECT)
    parser.add_argument("--revision", default=DEFAULT_PROJECT)
    parser.add_argument("--clock-name", default=DEFAULT_CLOCK)
    parser.add_argument("--min-wns", type=float, default=DEFAULT_MIN_WNS)
    parser.add_argument("--log-dir", type=Path, required=True)
    parser.add_argument("--quartus-syn", default="quartus_syn")
    parser.add_argument("--quartus-sh", default="quartus_sh")
    parser.add_argument("--notify", type=int, choices=(0, 1), default=0)
    parser.add_argument(
        "--notify-tool", type=Path, default=Path("tools/send_workflow_ping.py")
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        project_dir = args.project_dir.resolve()
        project_file = project_dir / f"{args.project}.qpf"
        revision_file = project_dir / f"{args.revision}.qsf"
        if not project_file.is_file():
            raise QuartusRunError(f"project file not found: {project_file}")
        if not revision_file.is_file():
            raise QuartusRunError(f"revision file not found: {revision_file}")

        command = command_for(args)
        resolved_executable = executable_path(command[0])
        if resolved_executable is None:
            raise QuartusRunError(
                f"{command[0]} is not on PATH; load the project-matched Quartus module"
            )
        command[0] = resolved_executable
        reports = report_paths(project_dir, args.revision, args.mode)
        repo_root = find_repo_root(project_dir)
        version = tool_version(command[0])
        plan = {
            "schema_version": 1,
            "mode": args.mode,
            "command": command,
            "quartus_version": version,
            "project_dir": str(project_dir),
            "project": args.project,
            "revision": args.revision,
            "clock_name": args.clock_name,
            "min_wns_ns": args.min_wns if args.mode == "full" else None,
            "required_reports": {name: str(path) for name, path in reports.items()},
        }
        if args.dry_run:
            print(json.dumps(plan, indent=2, sort_keys=True))
            return 0

        log_dir = args.log_dir.resolve()
        if log_dir.exists() and any(log_dir.iterdir()):
            raise QuartusRunError(f"refusing nonempty log directory: {log_dir}")
        log_dir.mkdir(parents=True, exist_ok=True)
        started_at = utc_now()
        started_epoch = time.time()
        started_monotonic = time.monotonic()
        stamps = {name: file_stamp(path) for name, path in reports.items()}
        status_before = git_text(repo_root, "status", "--short") or "clean"
        plan.update(
            {
                "started_at": started_at,
                "log_dir": str(log_dir),
                "git_commit": git_text(repo_root, "rev-parse", "HEAD"),
                "git_status_before": status_before,
                "report_stamps_before": {
                    name: asdict(stamp) for name, stamp in stamps.items()
                },
            }
        )
        write_json(log_dir / "plan.json", plan)
        run_log = log_dir / "quartus.log"
        if args.notify:
            send_notification(
                args.notify_tool.resolve(),
                "compile-start",
                "mid",
                args.mode,
                "START",
                run_log,
                "Starting local Quartus flow: " + shlex.join(command),
            )

        returncode = stream_command(command, project_dir, run_log)
        reasons: list[str] = []
        fresh = {
            name: is_fresh(path, stamps[name], started_epoch)
            for name, path in reports.items()
        }
        for name, path in reports.items():
            if not path.is_file():
                reasons.append(f"missing required {name} report: {path}")
            elif not fresh[name]:
                reasons.append(f"required {name} report is stale: {path}")

        report_text = {name: read_text(path) for name, path in reports.items()}
        log_text = read_text(run_log)
        if returncode != 0:
            reasons.append(f"Quartus exited with status {returncode}")
        if contains_quartus_error(log_text, *report_text.values()):
            reasons.append("Quartus error marker found")

        flow_status: str | None = None
        setup_wns: float | None = None
        setup_tns: float | None = None
        timing_gate_failed = False
        if args.mode == "full":
            flow_status = parse_flow_status(reports["flow"])
            if flow_status is None:
                reasons.append("flow status is missing")
            elif "successful" not in flow_status.lower():
                reasons.append(f"flow status is {flow_status}")
            setup_wns, setup_tns = parse_setup_timing(reports["sta"], args.clock_name)
            if setup_wns is None:
                reasons.append(f"setup WNS for {args.clock_name} is missing")
            elif setup_wns < args.min_wns:
                timing_gate_failed = True
                reasons.append(
                    f"setup WNS {setup_wns:.3f} ns is below {args.min_wns:.3f} ns"
                )

        if reasons:
            status = (
                "timing_fail"
                if timing_gate_failed and len(reasons) == 1
                else "compile_fail"
            )
        else:
            status = "pass"
        result = CompileResult(
            schema_version=1,
            mode=args.mode,
            status=status,
            returncode=returncode,
            started_at=started_at,
            completed_at=utc_now(),
            duration_seconds=round(time.monotonic() - started_monotonic, 3),
            command=command,
            quartus_version=version,
            project_dir=str(project_dir),
            project=args.project,
            revision=args.revision,
            clock_name=args.clock_name,
            min_wns_ns=args.min_wns if args.mode == "full" else None,
            setup_wns_ns=setup_wns,
            setup_tns_ns=setup_tns,
            flow_status=flow_status,
            reasons=reasons,
            log=str(run_log),
            reports={name: str(path) for name, path in reports.items()},
            git_commit=git_text(repo_root, "rev-parse", "HEAD"),
            git_status_before=status_before,
            git_status_after=git_text(repo_root, "status", "--short") or "clean",
        )
        write_json(log_dir / "result.json", asdict(result))

        if status == "pass":
            detail = f"Quartus {args.mode} passed."
            if setup_wns is not None:
                detail += f" {args.clock_name} WNS={setup_wns:.3f} ns."
            print(detail)
        else:
            print(f"Quartus {args.mode} failed classification:", file=sys.stderr)
            for reason in reasons:
                print(f"  - {reason}", file=sys.stderr)
        print(f"Result: {log_dir / 'result.json'}")

        if args.notify:
            if status == "pass":
                event, priority = "compile-finish", "mid"
            elif status == "timing_fail":
                event, priority = "timing-error", "high"
            else:
                event, priority = "compile-error", "high"
            send_notification(
                args.notify_tool.resolve(),
                event,
                priority,
                args.mode,
                status.upper(),
                run_log,
                detail if status == "pass" else " | ".join(reasons),
            )
        return 0 if status == "pass" else 1
    except (OSError, QuartusRunError, ValueError) as exc:
        print(f"run_quartus.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
