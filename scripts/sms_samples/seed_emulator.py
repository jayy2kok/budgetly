#!/usr/bin/env python
"""Seed a running Android emulator's SMS inbox from the Budgetly sample fixture.

Usage
-----
    python scripts/sms_samples/seed_emulator.py \
        --fixture app/test/fixtures/sample_inbox.json

The messages are injected with ``adb emu sms send``, so the app's regular
``SmsInboxReader`` pipeline reads them exactly like real bank SMS. Start the
emulator first (``flutter emulators --launch <id>``) and boot the app with a
raised sync cap to ingest all of them:

    flutter run --dart-define=SMS_SYNC_MAX_MESSAGES=100

Only emulators are supported -- ``adb emu`` talks to the emulator console and
cannot inject messages into a physical device.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time

# Message bodies contain characters outside the Windows cp1252 console
# charset (e.g. the rupee sign U+20B9). Print as UTF-8 instead of crashing.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:  # Python < 3.7
        pass


def run(args: list[str], check: bool = True) -> subprocess.CompletedProcess:
    completed = subprocess.run(
        args,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if check and completed.returncode != 0:
        raise RuntimeError(
            f"command failed ({completed.returncode}): {' '.join(args)}\n"
            f"{completed.stderr.strip()}"
        )
    return completed


def list_emulators() -> list[str]:
    output = run(["adb", "devices"]).stdout
    emulators: list[str] = []
    for line in output.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith("emulator-") and parts[1] == "device":
            emulators.append(parts[0])
    return emulators


def sanitize(text: str) -> str:
    """Collapse newlines so the emulator console keeps the body on one line."""
    return " ".join(text.splitlines()).strip()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", help="emulator serial (default: first emulator)")
    parser.add_argument(
        "--fixture",
        default="app/test/fixtures/sample_inbox.json",
        help="fixture path (default: %(default)s)",
    )
    parser.add_argument("--limit", type=int, help="seed only the first N messages")
    parser.add_argument(
        "--delay",
        type=float,
        default=0.05,
        help="seconds to wait between injections (default: %(default)s)",
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="print what would be sent"
    )
    args = parser.parse_args()

    serial = args.serial
    if not serial:
        emulators = list_emulators()
        if not emulators:
            print(
                "No running emulator found. Start one first "
                "(flutter emulators --launch <id>).",
                file=sys.stderr,
            )
            return 1
        serial = emulators[0]

    with open(args.fixture, encoding="utf-8") as fh:
        payload = json.load(fh)
    messages = payload["messages"]
    if args.limit is not None:
        messages = messages[: args.limit]

    print(
        f"Seeding {len(messages)} messages into {serial} "
        f"from {args.fixture} ..."
    )

    failures = 0
    for index, message in enumerate(messages, 1):
        sender = sanitize(message["sender"])
        body = sanitize(message["body"])
        if args.dry_run:
            print(f"[{index}/{len(messages)}] {sender}: {body[:80]}")
            continue

        result = run(
            ["adb", "-s", serial, "emu", "sms", "send", sender, body],
            check=False,
        )
        if result.returncode != 0:
            failures += 1
            print(
                f"[{index}/{len(messages)}] FAILED {sender}: "
                f"{result.stderr.strip() or result.stdout.strip()}",
                file=sys.stderr,
            )
        elif index % 10 == 0 or index == len(messages):
            print(f"[{index}/{len(messages)}] injected")

        if args.delay:
            time.sleep(args.delay)

    if args.dry_run:
        print("Dry run complete; nothing was sent.")
    elif failures:
        print(f"Done with {failures} failure(s).", file=sys.stderr)
    else:
        print(f"Done: {len(messages)} messages injected into {serial}.")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
