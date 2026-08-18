#!/usr/bin/env python3
"""Classify WPPP expected-fail reproducers without mixing them into pass tiers."""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import shlex
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class ReproSpec:
    name: str
    marker: str


@dataclass
class ReproResult:
    name: str
    status: str
    returncode: int
    duration_seconds: float
    marker: str
    marker_seen: bool
    make_log: str
    vsim_log: str


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def parse_spec(value: str) -> ReproSpec:
    if "::" not in value:
        raise argparse.ArgumentTypeError("reproducer must be TEST::MARKER")
    name, marker = value.split("::", 1)
    if not name or not marker:
        raise argparse.ArgumentTypeError("reproducer must have a nonempty test and marker")
    return ReproSpec(name, marker)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def send_notification(
    tool: Path, event: str, priority: str, status: str, log_dir: Path, body: str
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
                "wppp expected-fail reproducers",
                "--status",
                status,
                "--log",
                str(log_dir),
                "--body",
                body,
            ],
            check=False,
        )
    except OSError as exc:
        print(f"warning: notification helper could not run: {exc}", file=sys.stderr)


def run_repro(spec: ReproSpec, cwd: Path, log_dir: Path) -> ReproResult:
    make_log = log_dir / f"{spec.name}.make.log"
    vsim_log = log_dir / f"{spec.name}.vsim.log"
    command = [
        "make",
        "--no-print-directory",
        "sim",
        "SIM_COMPILE=0",
        f"SIM_RUN_NAME={spec.name}",
        f"SIM_LOG_DIR={log_dir}",
        f"SIM_PLUSARGS=+{spec.name}",
        "SIM_WLF=0",
        "WORKFLOW_NOTIFY=0",
    ]
    start = time.monotonic()
    with make_log.open("w", encoding="utf-8") as handle:
        handle.write("Command: " + shlex.join(command) + "\n")
        handle.flush()
        proc = subprocess.run(
            command,
            cwd=cwd,
            check=False,
            stdout=handle,
            stderr=subprocess.STDOUT,
            text=True,
        )
    transcript = vsim_log.read_text(encoding="utf-8", errors="replace") if vsim_log.is_file() else ""
    marker_seen = spec.marker in transcript
    pass_seen = f"WPPP_TEST_PASS: {spec.name}" in transcript
    if marker_seen:
        status = "XFAIL"
    elif proc.returncode == 0 and pass_seen:
        status = "XPASS"
    else:
        status = "FAIL"
    result = ReproResult(
        name=spec.name,
        status=status,
        returncode=proc.returncode,
        duration_seconds=round(time.monotonic() - start, 3),
        marker=spec.marker,
        marker_seen=marker_seen,
        make_log=str(make_log),
        vsim_log=str(vsim_log),
    )
    (log_dir / f"{spec.name}.status").write_text(status + "\n", encoding="utf-8")
    write_json(log_dir / f"{spec.name}.result.json", asdict(result))
    print(f"[wppp-repro] {status:<5} {spec.name}", flush=True)
    return result


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reproducers", nargs="+", type=parse_spec)
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    parser.add_argument("--log-dir", type=Path, required=True)
    parser.add_argument("--jobs", type=int, default=2)
    parser.add_argument("--notify", type=int, choices=(0, 1), default=0)
    parser.add_argument(
        "--notify-tool", type=Path, default=Path("../tools/send_workflow_ping.py")
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    if args.jobs < 1:
        print("run_repro.py: --jobs must be positive", file=sys.stderr)
        return 2
    if args.dry_run:
        print(json.dumps([asdict(spec) for spec in args.reproducers], indent=2))
        return 0
    cwd = args.cwd.resolve()
    log_dir = args.log_dir.resolve()
    if log_dir.exists() and any(log_dir.iterdir()):
        print(f"run_repro.py: refusing nonempty log directory: {log_dir}", file=sys.stderr)
        return 2
    log_dir.mkdir(parents=True, exist_ok=True)
    started_at = utc_now()
    write_json(
        log_dir / "plan.json",
        {
            "schema_version": 1,
            "started_at": started_at,
            "jobs": args.jobs,
            "cwd": str(cwd),
            "reproducers": [asdict(spec) for spec in args.reproducers],
        },
    )
    if args.notify:
        send_notification(
            args.notify_tool.resolve(),
            "regression-start",
            "mid",
            "START",
            log_dir,
            f"Starting {len(args.reproducers)} WPPP expected-fail reproducers.",
        )
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(lambda spec: run_repro(spec, cwd, log_dir), args.reproducers))
    bad = [result for result in results if result.status != "XFAIL"]
    write_json(
        log_dir / "summary.json",
        {
            "schema_version": 1,
            "started_at": started_at,
            "completed_at": utc_now(),
            "status": "fail" if bad else "xfail",
            "results": [asdict(result) for result in results],
        },
    )
    if args.notify:
        send_notification(
            args.notify_tool.resolve(),
            "test-error" if bad else "regression-finish",
            "high" if bad else "mid",
            "FAIL" if bad else "XFAIL",
            log_dir,
            (
                "Unexpected classifications: "
                + ", ".join(f"{result.name}={result.status}" for result in bad)
                if bad
                else f"All {len(results)} known WPPP defects reproduced as expected."
            ),
        )
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
