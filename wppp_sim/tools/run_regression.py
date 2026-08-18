#!/usr/bin/env python3
"""Run WPPP expected-pass simulations and write durable JSON evidence."""

from __future__ import annotations

import argparse
import concurrent.futures
import gzip
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


ERROR_PATTERNS = (
    re.compile(r"WPPP_(?:INT_)?(?:CHECK_ERROR|TEST_FAIL):"),
    re.compile(r"# \*\* (?:Fatal|Error):", re.IGNORECASE),
    re.compile(r"Errors:\s*[1-9][0-9]*\b"),
)


class RegressionError(RuntimeError):
    pass


@dataclass(frozen=True)
class TestSpec:
    name: str
    plusargs: list[str]
    estimate_seconds: float


@dataclass
class TestResult:
    name: str
    status: str
    returncode: int
    duration_seconds: float
    estimate_seconds: float
    plusargs: list[str]
    error_markers: list[str]
    completion_seen: bool
    make_log: str
    vsim_log: str
    verbose_make_log: str = ""
    verbose_vsim_log: str = ""


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def announce(message: str) -> None:
    print(message, flush=True)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def git_text(cwd: Path, *args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    return proc.stdout.strip() if proc.returncode == 0 else "unknown"


def read_history(path: Path | None, profile: str) -> dict[str, float]:
    if path is None or not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
        raw = value.get("durations", {}).get(profile, {})
        return {str(name): float(seconds) for name, seconds in raw.items()}
    except (OSError, ValueError, TypeError, json.JSONDecodeError):
        return {}


def make_schedule(
    tests: list[str], profile: str, history: dict[str, float], extra_plusargs: list[str]
) -> list[TestSpec]:
    if len(tests) != len(set(tests)):
        raise RegressionError("test names must be unique")
    schedule: list[TestSpec] = []
    for index, name in enumerate(tests):
        if not re.fullmatch(r"RUN_[A-Z0-9_]+", name):
            raise RegressionError(f"invalid test name: {name}")
        estimate = history.get(name, float(len(tests) - index))
        schedule.append(
            TestSpec(name=name, plusargs=[f"+{name}", *extra_plusargs], estimate_seconds=estimate)
        )
    return sorted(schedule, key=lambda spec: (-spec.estimate_seconds, spec.name))


def find_error_markers(text: str) -> list[str]:
    markers: list[str] = []
    for line in text.splitlines():
        if any(pattern.search(line) for pattern in ERROR_PATTERNS):
            markers.append(line.strip())
            if len(markers) == 12:
                break
    return markers


def classify(name: str, returncode: int, transcript: str) -> tuple[str, list[str], bool]:
    markers = find_error_markers(transcript)
    completion_seen = f"WPPP_TEST_PASS: {name}" in transcript
    status = "PASS" if returncode == 0 and not markers and completion_seen else "FAIL"
    if returncode != 0:
        markers.insert(0, f"process exit={returncode}")
    if not completion_seen:
        markers.append("missing WPPP_TEST_PASS completion marker")
    return status, markers, completion_seen


def run_make(
    spec: TestSpec,
    run_name: str,
    cwd: Path,
    log_dir: Path,
    make_command: list[str],
    retain_wlf: bool,
) -> tuple[int, float, Path, Path]:
    make_log = log_dir / f"{run_name}.make.log"
    vsim_log = log_dir / f"{run_name}.vsim.log"
    command = [
        *make_command,
        "--no-print-directory",
        "sim",
        "SIM_COMPILE=0",
        f"SIM_RUN_NAME={run_name}",
        f"SIM_LOG_DIR={log_dir}",
        f"SIM_PLUSARGS={' '.join(spec.plusargs)}",
        f"SIM_WLF={1 if retain_wlf else 0}",
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
    return proc.returncode, time.monotonic() - start, make_log, vsim_log


def compress(path: Path) -> Path:
    destination = path.with_suffix(path.suffix + ".gz")
    with path.open("rb") as source, gzip.open(destination, "wb") as target:
        shutil.copyfileobj(source, target)
    path.unlink()
    return destination


def run_test(
    spec: TestSpec,
    cwd: Path,
    log_dir: Path,
    make_command: list[str],
    compress_pass_logs: bool,
    rerun_failures: bool,
    failure_wlf: bool,
) -> TestResult:
    announce(f"[wppp-sim] START {spec.name}")
    returncode, duration, make_log, vsim_log = run_make(
        spec, spec.name, cwd, log_dir, make_command, False
    )
    transcript = vsim_log.read_text(encoding="utf-8", errors="replace") if vsim_log.is_file() else ""
    status, markers, completion_seen = classify(spec.name, returncode, transcript)

    verbose_make: Path | None = None
    verbose_vsim: Path | None = None
    if status != "PASS" and rerun_failures:
        verbose_name = f"{spec.name}.verbose"
        verbose_rc, _, verbose_make, verbose_vsim = run_make(
            spec, verbose_name, cwd, log_dir, make_command, failure_wlf
        )
        verbose_text = (
            verbose_vsim.read_text(encoding="utf-8", errors="replace")
            if verbose_vsim.is_file()
            else ""
        )
        verbose_status, verbose_markers, verbose_completion = classify(
            spec.name, verbose_rc, verbose_text
        )
        if verbose_status == "PASS":
            status = "FLAKY"
            markers.append("verbose rerun passed after initial failure")
        else:
            markers.extend(f"verbose: {marker}" for marker in verbose_markers)
        completion_seen = completion_seen or verbose_completion

    if status == "PASS" and compress_pass_logs:
        if make_log.is_file():
            make_log = compress(make_log)
        if vsim_log.is_file():
            vsim_log = compress(vsim_log)

    result = TestResult(
        name=spec.name,
        status=status,
        returncode=returncode,
        duration_seconds=round(duration, 3),
        estimate_seconds=spec.estimate_seconds,
        plusargs=spec.plusargs,
        error_markers=markers,
        completion_seen=completion_seen,
        make_log=str(make_log),
        vsim_log=str(vsim_log),
        verbose_make_log=str(verbose_make) if verbose_make is not None else "",
        verbose_vsim_log=str(verbose_vsim) if verbose_vsim is not None else "",
    )
    (log_dir / f"{spec.name}.status").write_text(status + "\n", encoding="utf-8")
    write_json(log_dir / f"{spec.name}.result.json", asdict(result))
    announce(f"[wppp-sim] {status:<5} {spec.name} ({duration:.2f}s)")
    return result


def update_history(
    path: Path | None, profile: str, previous: dict[str, float], results: list[TestResult]
) -> None:
    if path is None:
        return
    root: dict[str, object] = {"schema_version": 1, "durations": {}}
    if path.is_file():
        try:
            loaded = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(loaded, dict):
                root = loaded
        except (OSError, json.JSONDecodeError):
            pass
    durations = root.setdefault("durations", {})
    if not isinstance(durations, dict):
        durations = {}
        root["durations"] = durations
    profile_values = dict(previous)
    for result in results:
        if result.status == "PASS":
            old = profile_values.get(result.name)
            profile_values[result.name] = round(
                result.duration_seconds if old is None else old * 0.7 + result.duration_seconds * 0.3,
                3,
            )
    durations[profile] = profile_values
    path.parent.mkdir(parents=True, exist_ok=True)
    write_json(path, root)


def send_notification(
    notify_tool: Path,
    event: str,
    priority: str,
    suite_name: str,
    profile: str,
    status: str,
    log_dir: Path,
    body: str,
) -> None:
    subprocess.run(
        [
            sys.executable,
            str(notify_tool),
            "--event",
            event,
            "--priority",
            priority,
            "--name",
            f"{suite_name} {profile} regression",
            "--status",
            status,
            "--log",
            str(log_dir),
            "--body",
            body,
        ],
        check=False,
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="+")
    parser.add_argument("--profile", choices=("smoke", "focused", "full"), default="full")
    parser.add_argument("--jobs", type=int, default=4)
    parser.add_argument("--log-dir", type=Path, required=True)
    parser.add_argument("--cwd", type=Path, default=Path.cwd())
    parser.add_argument("--make-command", default="make")
    parser.add_argument("--suite-name", default="wppp")
    parser.add_argument("--history-file", type=Path)
    parser.add_argument("--extra-plusarg", action="append", default=[])
    parser.add_argument("--compress-pass-logs", type=int, choices=(0, 1), default=1)
    parser.add_argument("--rerun-failures", type=int, choices=(0, 1), default=1)
    parser.add_argument("--failure-wlf", type=int, choices=(0, 1), default=0)
    parser.add_argument("--notify", type=int, choices=(0, 1), default=0)
    parser.add_argument(
        "--notify-tool", type=Path, default=Path("../tools/send_workflow_ping.py")
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if args.jobs < 1:
            raise RegressionError("--jobs must be positive")
        cwd = args.cwd.resolve()
        if not (cwd / "Makefile").is_file():
            raise RegressionError(f"simulation Makefile not found under {cwd}")
        history_path = args.history_file.resolve() if args.history_file else None
        history = read_history(history_path, args.profile)
        schedule = make_schedule(args.tests, args.profile, history, args.extra_plusarg)
        plan: dict[str, object] = {
            "suite_name": args.suite_name,
            "profile": args.profile,
            "jobs": args.jobs,
            "ordered_tests": [asdict(spec) for spec in schedule],
        }
        if args.dry_run:
            print(json.dumps(plan, indent=2, sort_keys=True))
            return 0

        log_dir = args.log_dir.resolve()
        if log_dir.exists() and any(log_dir.iterdir()):
            raise RegressionError(f"refusing nonempty log directory: {log_dir}")
        log_dir.mkdir(parents=True, exist_ok=True)
        make_command = shlex.split(args.make_command)
        if not make_command:
            raise RegressionError("--make-command is empty")
        if shutil.which(make_command[0]) is None and not Path(make_command[0]).exists():
            raise RegressionError(f"make command not found: {make_command[0]}")

        started_at = utc_now()
        plan.update(
            {
                "schema_version": 1,
                "started_at": started_at,
                "cwd": str(cwd),
                "log_dir": str(log_dir),
                "git_commit": git_text(cwd, "rev-parse", "HEAD"),
                "git_tracked_status": git_text(
                    cwd, "status", "--short", "--untracked-files=no"
                )
                or "clean",
                "make_command": make_command,
            }
        )
        write_json(log_dir / "plan.json", plan)
        if args.notify:
            send_notification(
                args.notify_tool.resolve(),
                "regression-start",
                "mid",
                args.suite_name,
                args.profile,
                "START",
                log_dir,
                f"Starting {len(schedule)} WPPP tests with {args.jobs} workers.",
            )

        results_by_name: dict[str, TestResult] = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = {
                pool.submit(
                    run_test,
                    spec,
                    cwd,
                    log_dir,
                    make_command,
                    bool(args.compress_pass_logs),
                    bool(args.rerun_failures),
                    bool(args.failure_wlf),
                ): spec
                for spec in schedule
            }
            for future in concurrent.futures.as_completed(futures):
                spec = futures[future]
                try:
                    results_by_name[spec.name] = future.result()
                except Exception as exc:  # Keep aggregate evidence on runner failures.
                    result = TestResult(
                        name=spec.name,
                        status="FAIL",
                        returncode=125,
                        duration_seconds=0.0,
                        estimate_seconds=spec.estimate_seconds,
                        plusargs=spec.plusargs,
                        error_markers=[f"runner exception: {exc}"],
                        completion_seen=False,
                        make_log="",
                        vsim_log="",
                    )
                    results_by_name[spec.name] = result
                    write_json(log_dir / f"{spec.name}.result.json", asdict(result))
                    (log_dir / f"{spec.name}.status").write_text("FAIL\n", encoding="utf-8")

        results = [results_by_name[spec.name] for spec in schedule]
        failures = [result for result in results if result.status != "PASS"]
        summary = {
            "schema_version": 1,
            "suite_name": args.suite_name,
            "profile": args.profile,
            "started_at": started_at,
            "completed_at": utc_now(),
            "status": "fail" if failures else "pass",
            "pass_count": len(results) - len(failures),
            "fail_count": len(failures),
            "results": [asdict(result) for result in results],
        }
        write_json(log_dir / "summary.json", summary)
        update_history(history_path, args.profile, history, results)

        announce("---- WPPP simulation summary ----")
        for result in results:
            announce(f"{result.name:<32} {result.status:<5} {result.duration_seconds:7.2f}s")
        announce(f"Results: {log_dir / 'summary.json'}")
        if args.notify:
            send_notification(
                args.notify_tool.resolve(),
                "test-error" if failures else "regression-finish",
                "high" if failures else "mid",
                args.suite_name,
                args.profile,
                "FAIL" if failures else "PASS",
                log_dir,
                (
                    "Failures: " + ", ".join(result.name for result in failures)
                    if failures
                    else f"All {len(results)} WPPP simulations passed."
                ),
            )
        return 1 if failures else 0
    except (RegressionError, OSError, ValueError) as exc:
        print(f"run_regression.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
