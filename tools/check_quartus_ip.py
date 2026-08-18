#!/usr/bin/env python3
"""Check whether Quartus IP/QIP synthesis collateral is present and coherent."""

from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import sys
from dataclasses import asdict, dataclass
from pathlib import Path


QSF_ASSIGNMENT_RE = re.compile(
    r"^\s*set_global_assignment\s+-name\s+(IP_FILE|QSYS_FILE|QIP_FILE)\s+(.+?)\s*$"
)
QIP_JOIN_RE = re.compile(
    r"\[file\s+join\s+\$::quartus\(qip_path\)\s+[\"{]([^\"}]+)[\"}]\]"
)


class CollateralError(RuntimeError):
    pass


@dataclass(frozen=True)
class Assignment:
    line: int
    kind: str
    value: str
    path: Path


@dataclass
class Inspection:
    schema_version: int
    status: str
    project_file: str
    assignment_count: int
    descriptor_count: int
    qip_count: int
    missing_descriptors: list[str]
    missing_qips: list[str]
    missing_qip_references: list[str]
    generation_inputs: list[str]


def strip_tcl_value(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and (value[0], value[-1]) in {("\"", "\""), ("{", "}")}:
        return value[1:-1]
    return value


def parse_assignments(qsf: Path) -> list[Assignment]:
    assignments: list[Assignment] = []
    for line_number, line in enumerate(qsf.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        match = QSF_ASSIGNMENT_RE.match(line)
        if not match:
            continue
        value = strip_tcl_value(match.group(2))
        if "$" in value or "[" in value:
            raise CollateralError(
                f"cannot resolve Tcl expression at {qsf}:{line_number}: {value}"
            )
        assignments.append(
            Assignment(line_number, match.group(1), value, (qsf.parent / value).resolve())
        )
    return assignments


def generated_qip(descriptor: Path) -> Path:
    return descriptor.parent / descriptor.stem / f"{descriptor.stem}.qip"


def companion_descriptor(qip: Path) -> Path:
    return qip.parent.parent / f"{qip.stem}.ip"


def qip_references(qip: Path) -> list[Path]:
    references: list[Path] = []
    for line in qip.read_text(encoding="utf-8", errors="replace").splitlines():
        for relative in QIP_JOIN_RE.findall(line):
            references.append((qip.parent / relative).resolve())
    return references


def display(path: Path, project_dir: Path) -> str:
    return os.path.relpath(path, project_dir)


def inspect(project_dir: Path, project: str) -> Inspection:
    project_dir = project_dir.resolve()
    qsf = project_dir / f"{project}.qsf"
    if not qsf.is_file():
        raise CollateralError(f"project settings file not found: {qsf}")
    assignments = parse_assignments(qsf)
    if not assignments:
        raise CollateralError(f"no IP/QSYS/QIP assignments found in {qsf}")

    descriptors: set[Path] = set()
    qips: set[Path] = set()
    qip_to_descriptor: dict[Path, Path] = {}
    for assignment in assignments:
        if assignment.kind in {"IP_FILE", "QSYS_FILE"}:
            descriptor = assignment.path
            qip = generated_qip(descriptor)
        else:
            qip = assignment.path
            descriptor = companion_descriptor(qip)
        descriptors.add(descriptor)
        qips.add(qip)
        qip_to_descriptor[qip] = descriptor

    missing_descriptors = sorted(path for path in descriptors if not path.is_file())
    missing_qips = sorted(path for path in qips if not path.is_file())
    missing_references: list[Path] = []
    generation_inputs: set[Path] = set()
    for qip in qips:
        descriptor = qip_to_descriptor[qip]
        if not qip.is_file():
            if descriptor.is_file():
                generation_inputs.add(descriptor)
            continue
        missing_for_qip = [path for path in qip_references(qip) if not path.exists()]
        missing_references.extend(missing_for_qip)
        if missing_for_qip and descriptor.is_file():
            generation_inputs.add(descriptor)

    problems = missing_descriptors or missing_qips or missing_references
    return Inspection(
        schema_version=1,
        status="incomplete" if problems else "ready",
        project_file=str(qsf),
        assignment_count=len(assignments),
        descriptor_count=len(descriptors),
        qip_count=len(qips),
        missing_descriptors=[display(path, project_dir) for path in missing_descriptors],
        missing_qips=[display(path, project_dir) for path in missing_qips],
        missing_qip_references=[
            display(path, project_dir) for path in sorted(set(missing_references))
        ],
        generation_inputs=[
            display(path, project_dir) for path in sorted(generation_inputs)
        ],
    )


def generation_command(result: Inspection, revision: str) -> list[str] | None:
    if not result.generation_inputs:
        return None
    first, *rest = result.generation_inputs
    return [
        "qsys-generate",
        first,
        *(f"--batch={value}" for value in rest),
        "--synthesis=VERILOG",
        f"--quartus-project={Path(result.project_file).name.removesuffix('.qsf')}.qpf",
        f"--rev={revision}",
        "--parallel=4",
    ]


def print_human(result: Inspection, max_details: int) -> None:
    print(f"Quartus IP collateral: {result.status.upper()}")
    print(
        f"Assignments={result.assignment_count} descriptors={result.descriptor_count} "
        f"QIPs={result.qip_count}"
    )
    groups = (
        ("Missing descriptors", result.missing_descriptors),
        ("Missing generated QIPs", result.missing_qips),
        ("Missing files referenced by QIPs", result.missing_qip_references),
    )
    for heading, values in groups:
        if not values:
            continue
        print(f"{heading}: {len(values)}")
        for value in values[:max_details]:
            print(f"  - {value}")
        if len(values) > max_details:
            print(f"  - ... {len(values) - max_details} more")
    if result.generation_inputs:
        print(f"Generation inputs required: {len(result.generation_inputs)}")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-dir", type=Path, default=Path("hardware_test_design"))
    parser.add_argument("--project", default="cxltyp2_ed")
    parser.add_argument("--revision", default="cxltyp2_ed")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--print-generation-command", action="store_true")
    parser.add_argument("--max-details", type=int, default=30)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        if args.max_details < 0:
            raise CollateralError("--max-details must not be negative")
        result = inspect(args.project_dir, args.project)
        if args.json:
            print(json.dumps(asdict(result), indent=2, sort_keys=True))
        else:
            print_human(result, args.max_details)
        if args.print_generation_command:
            command = generation_command(result, args.revision)
            if command:
                print("\nRun from the project directory after reviewing generated-file impact:")
                print(shlex.join(command))
            else:
                print("\nNo IP generation command is required.")
            return 0
        return 0 if result.status == "ready" else 1
    except (CollateralError, OSError, ValueError) as exc:
        print(f"check_quartus_ip.py: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
