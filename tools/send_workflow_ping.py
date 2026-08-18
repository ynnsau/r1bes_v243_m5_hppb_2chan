#!/usr/bin/env python3
"""Send a best-effort WPPP workflow notification.

The helper uses only the Python standard library. It supports Pushover, SMTP,
or a local sendmail binary; credentials remain in the environment and are
redacted from dry-run output. Delivery failures are warnings unless --strict
is requested, so a valid simulation or compile is never reclassified solely
because the notification path is unavailable.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import shutil
import smtplib
import socket
import subprocess
import sys
from datetime import datetime
from email.message import EmailMessage
from email.utils import formatdate, make_msgid
from pathlib import Path
from urllib import error as urlerror
from urllib import parse, request


DEFAULT_RECIPIENT = "yans3@illinois.edu"
PUSHOVER_API_URL = "https://api.pushover.net/1/messages.json"
PUSHOVER_MAX_MESSAGE_CHARS = 1024
PUSHOVER_MAX_TITLE_CHARS = 250
PRIORITIES = ("low", "mid", "high")
PUSHOVER_PRIORITIES = {"low": -1, "mid": 0, "high": 1}
EVENT_DEFAULT_PRIORITY = {
    "workflow-start": "mid",
    "workflow-stop": "mid",
    "workflow-finish": "mid",
    "checkpoint": "mid",
    "regression-start": "mid",
    "regression-finish": "mid",
    "test-error": "high",
    "compile-start": "mid",
    "compile-finish": "mid",
    "compile-error": "high",
    "timing-error": "high",
    "tool-error": "high",
    "command-start": "mid",
    "command-finish": "mid",
    "command-error": "high",
}
EVENT_LABELS = {event: event.replace("-", " ") for event in EVENT_DEFAULT_PRIORITY}


def run_git(args: list[str], fallback: str) -> str:
    try:
        proc = subprocess.run(
            ["git", *args],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except OSError:
        return fallback
    value = proc.stdout.strip()
    return value if proc.returncode == 0 and value else fallback


def env_first(*names: str) -> str | None:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    return None


def effective_priority(args: argparse.Namespace) -> str | None:
    value = args.priority or os.environ.get("WORKFLOW_PING_PRIORITY")
    if value:
        value = value.lower()
        if value not in PRIORITIES:
            raise ValueError(f"unknown workflow priority: {value}")
        return value
    return EVENT_DEFAULT_PRIORITY.get(args.event) if args.event else None


def default_subject(args: argparse.Namespace) -> str:
    project = os.environ.get("WORKFLOW_PROJECT", "wppp")
    branch = run_git(["branch", "--show-current"], "detached-or-unknown")
    priority = effective_priority(args)
    priority_text = f"[{priority}]" if priority else ""
    name_text = f": {args.name}" if args.name else ""
    label = EVENT_LABELS.get(args.event, args.event or "workflow ping")
    return f"[{project}]{priority_text} {label}{name_text}: {branch}"


def default_from_address() -> str:
    return env_first("WORKFLOW_EMAIL_FROM", "SMTP_FROM", "EMAIL_FROM") or (
        f"{getpass.getuser()}@{socket.getfqdn()}"
    )


def git_status_summary() -> str:
    branch = run_git(["branch", "--show-current"], "detached-or-unknown")
    head = run_git(["log", "-1", "--oneline"], "unknown")
    tracked = run_git(
        ["status", "--short", "--untracked-files=no"], "git status unavailable"
    )
    if not tracked:
        tracked = "tracked worktree clean"
    return "\n".join(
        [
            f"Time: {datetime.now().astimezone().isoformat(timespec='seconds')}",
            f"Host: {socket.gethostname()}",
            f"Path: {Path.cwd()}",
            f"Branch: {branch}",
            f"HEAD: {head}",
            "",
            "Tracked status:",
            tracked,
        ]
    )


def workflow_summary(args: argparse.Namespace) -> str:
    lines: list[str] = []
    priority = effective_priority(args)
    for label, value in (
        ("Event", args.event),
        ("Priority", priority),
        ("Name", args.name),
        ("Status", args.status),
        ("Command", args.command),
    ):
        if value:
            lines.append(f"{label}: {value}")
    lines.extend(f"Log: {value}" for value in args.log or [])
    lines.extend(f"Detail: {value}" for value in args.detail or [])
    return "\n".join(lines)


def read_body(args: argparse.Namespace) -> str:
    chunks = [git_status_summary()]
    summary = workflow_summary(args)
    if summary:
        chunks.extend(["", "Workflow event:", summary])
    extra = ""
    if args.body_file:
        extra = Path(args.body_file).read_text(encoding="utf-8")
    elif args.body:
        extra = args.body
    elif not sys.stdin.isatty():
        extra = sys.stdin.read()
    if extra.strip():
        chunks.extend(["", "Workflow update:", extra.rstrip()])
    return "\n".join(chunks).rstrip() + "\n"


def recipients(values: list[str] | None) -> list[str]:
    if not values:
        return [os.environ.get("WORKFLOW_EMAIL_TO", DEFAULT_RECIPIENT)]
    parsed = [piece.strip() for value in values for piece in value.split(",") if piece.strip()]
    return parsed or [DEFAULT_RECIPIENT]


def build_message(args: argparse.Namespace) -> EmailMessage:
    message = EmailMessage()
    message["From"] = args.from_address or default_from_address()
    message["To"] = ", ".join(recipients(args.to))
    message["Subject"] = args.subject or default_subject(args)
    message["Date"] = formatdate(localtime=True)
    message["Message-ID"] = make_msgid(domain=socket.getfqdn())
    message.set_content(read_body(args))
    return message


def pushover_token(args: argparse.Namespace) -> str | None:
    return args.pushover_token or env_first("PUSHOVER_APP_TOKEN", "PUSHOVER_TOKEN")


def pushover_user(args: argparse.Namespace) -> str | None:
    return args.pushover_user or env_first("PUSHOVER_USER_KEY", "PUSHOVER_USER")


def select_transports(args: argparse.Namespace) -> list[str]:
    if args.pushover:
        return ["pushover"]
    selected = (args.transport or os.environ.get("WORKFLOW_PING_TRANSPORT", "auto")).lower()
    if selected == "auto":
        return ["pushover"] if pushover_token(args) and pushover_user(args) else ["email"]
    if selected == "all":
        return ["pushover", "email"]
    if selected in {"pushover", "email"}:
        return [selected]
    raise ValueError(f"unknown notification transport: {selected}")


def truncate(value: str, maximum: int) -> str:
    if maximum <= 0 or len(value) <= maximum:
        return value
    suffix = "\n...[truncated]"
    return value[: max(0, maximum - len(suffix))] + suffix


def pushover_payload(args: argparse.Namespace, message: EmailMessage) -> dict[str, str]:
    token = pushover_token(args)
    user = pushover_user(args)
    if not token or not user:
        raise RuntimeError(
            "Pushover is not configured; set PUSHOVER_APP_TOKEN and PUSHOVER_USER_KEY"
        )
    payload = {
        "token": token,
        "user": user,
        "title": truncate(str(message["Subject"]), PUSHOVER_MAX_TITLE_CHARS),
        "message": truncate(message.get_content().rstrip(), args.pushover_max_chars),
    }
    optional = {
        "device": args.pushover_device or os.environ.get("PUSHOVER_DEVICE"),
        "sound": args.pushover_sound or os.environ.get("PUSHOVER_SOUND"),
        "url": args.pushover_url or os.environ.get("PUSHOVER_URL"),
        "url_title": args.pushover_url_title or os.environ.get("PUSHOVER_URL_TITLE"),
    }
    payload.update({key: value for key, value in optional.items() if value})
    priority = args.pushover_priority
    generic = effective_priority(args)
    if priority is None and generic:
        priority = PUSHOVER_PRIORITIES[generic]
    if priority is None and os.environ.get("PUSHOVER_PRIORITY"):
        priority = int(os.environ["PUSHOVER_PRIORITY"])
    if priority is not None:
        payload["priority"] = str(priority)
    ttl = args.pushover_ttl
    if ttl is None and os.environ.get("PUSHOVER_TTL"):
        ttl = int(os.environ["PUSHOVER_TTL"])
    if ttl is not None:
        payload["ttl"] = str(ttl)
    return payload


def send_pushover(args: argparse.Namespace, message: EmailMessage) -> str:
    payload = pushover_payload(args, message)
    api_url = args.pushover_api_url or os.environ.get("PUSHOVER_API_URL", PUSHOVER_API_URL)
    req = request.Request(
        api_url,
        data=parse.urlencode(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": "wppp-workflow-ping/1.0",
        },
        method="POST",
    )
    try:
        with request.urlopen(req, timeout=args.timeout) as response:
            body = response.read().decode("utf-8", errors="replace")
    except urlerror.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Pushover HTTP {exc.code}: {body[:300]}") from exc
    parsed = json.loads(body)
    if parsed.get("status") != 1:
        raise RuntimeError(f"Pushover rejected message: {parsed}")
    return str(parsed.get("request", "unknown-request"))


def find_sendmail(explicit: str | None) -> str | None:
    if explicit:
        return explicit
    for candidate in ("/usr/sbin/sendmail", "/usr/lib/sendmail"):
        if Path(candidate).exists():
            return candidate
    return shutil.which("sendmail")


def send_email(args: argparse.Namespace, message: EmailMessage) -> str:
    host = args.smtp_host or os.environ.get("SMTP_HOST")
    if host:
        port = args.smtp_port or int(os.environ.get("SMTP_PORT", "587"))
        user = args.smtp_user or os.environ.get("SMTP_USER")
        password = args.smtp_password or os.environ.get("SMTP_PASS", "")
        use_ssl = args.smtp_ssl or os.environ.get("SMTP_SSL", "").lower() in {
            "1",
            "true",
            "yes",
        }
        smtp_class = smtplib.SMTP_SSL if use_ssl else smtplib.SMTP
        with smtp_class(host, port, timeout=args.timeout) as smtp:
            if not use_ssl and not args.no_starttls:
                smtp.starttls()
            if user:
                smtp.login(user, password)
            smtp.send_message(message)
    else:
        binary = find_sendmail(args.sendmail or os.environ.get("SENDMAIL"))
        if not binary:
            raise RuntimeError(
                "email is not configured; set SMTP_HOST or provide a sendmail binary"
            )
        proc = subprocess.run([binary, "-t", "-oi"], input=message.as_bytes(), check=False)
        if proc.returncode != 0:
            raise RuntimeError(f"sendmail exited with status {proc.returncode}")
    return str(message["To"])


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--transport", choices=("auto", "email", "pushover", "all"))
    parser.add_argument("--pushover", action="store_true", help="shortcut for --transport pushover")
    parser.add_argument("--to", action="append", help="recipient email; may be repeated")
    parser.add_argument("--from-address")
    parser.add_argument("--subject")
    parser.add_argument("--body")
    parser.add_argument("--body-file")
    parser.add_argument("--event", choices=tuple(EVENT_DEFAULT_PRIORITY))
    parser.add_argument("--priority", choices=PRIORITIES)
    parser.add_argument("--name")
    parser.add_argument("--status")
    parser.add_argument("--command")
    parser.add_argument("--log", action="append")
    parser.add_argument("--detail", action="append")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--smtp-host")
    parser.add_argument("--smtp-port", type=int)
    parser.add_argument("--smtp-user")
    parser.add_argument("--smtp-password")
    parser.add_argument("--smtp-ssl", action="store_true")
    parser.add_argument("--no-starttls", action="store_true")
    parser.add_argument("--sendmail")
    parser.add_argument("--timeout", type=float, default=30.0)
    parser.add_argument("--pushover-token")
    parser.add_argument("--pushover-user")
    parser.add_argument("--pushover-device")
    parser.add_argument("--pushover-priority", type=int)
    parser.add_argument("--pushover-sound")
    parser.add_argument("--pushover-url")
    parser.add_argument("--pushover-url-title")
    parser.add_argument("--pushover-ttl", type=int)
    parser.add_argument("--pushover-api-url", default=PUSHOVER_API_URL)
    parser.add_argument("--pushover-max-chars", type=int, default=PUSHOVER_MAX_MESSAGE_CHARS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        message = build_message(args)
        transports = select_transports(args)
        if args.dry_run:
            if "email" in transports:
                print("== email ==")
                sys.stdout.write(message.as_string())
                if not message.as_string().endswith("\n"):
                    print()
            if "pushover" in transports:
                safe = {
                    key: "<redacted>" if key in {"token", "user"} else value
                    for key, value in pushover_payload(args, message).items()
                }
                print("== pushover ==")
                print(json.dumps(safe, indent=2, sort_keys=True))
            return 0

        failures: list[str] = []
        successes: list[str] = []
        for transport in transports:
            try:
                if transport == "pushover":
                    successes.append(f"Pushover request={send_pushover(args, message)}")
                else:
                    successes.append(f"email to {send_email(args, message)}")
            except Exception as exc:  # Best-effort by design.
                failures.append(f"{transport}: {exc}")
                print(f"warning: workflow {transport} notification not sent: {exc}", file=sys.stderr)
        for success in successes:
            print(f"sent workflow ping through {success}")
        return 2 if failures and args.strict else 0
    except (OSError, ValueError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"send_workflow_ping.py: {exc}", file=sys.stderr)
        return 2 if args.strict else 0


if __name__ == "__main__":
    raise SystemExit(main())
