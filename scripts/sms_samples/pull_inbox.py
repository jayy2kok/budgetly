#!/usr/bin/env python
"""Pull the most recent SMS inbox rows from a connected Android device and
write them as the Budgetly sample-inbox fixture.

Usage
-----
    python scripts/sms_samples/pull_inbox.py --count 100 \
        --out app/test/fixtures/sample_inbox.json

Notes
-----
* Uses ``adb shell content query`` against ``content://sms/`` (type=1 inbox).
* The stock ``content`` tool on many OEM builds rejects ``--limit``, so all rows
  are fetched and the newest ``--count`` are kept in Python.
* Bodies may contain newlines; the parser handles them.
* No scrubbing is performed -- the output contains the device's real SMS.
"""

from __future__ import annotations

import argparse
import datetime
import json
import re
import subprocess
import sys

ROW_RE = re.compile(
    r"^Row: (\d+) address=(.*?), body=(.*?), date=(\d+), type=(\d+)$",
    re.MULTILINE | re.DOTALL,
)

QUERY = (
    "content query --uri content://sms/ "
    "--projection address:body:date:type"
)


def run(args: list[str]) -> str:
    completed = subprocess.run(
        args,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if completed.returncode != 0:
        raise RuntimeError(
            f"command failed ({completed.returncode}): {' '.join(args)}\n"
            f"{completed.stderr.strip()}"
        )
    return completed.stdout


def list_devices() -> list[str]:
    output = run(["adb", "devices"])
    devices: list[str] = []
    for line in output.splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            devices.append(parts[0])
    return devices


def parse_rows(raw: str) -> list[dict]:
    return [
        {
            "row": int(m.group(1)),
            "sender": m.group(2),
            "body": m.group(3),
            "date": int(m.group(4)),
            "type": int(m.group(5)),
        }
        for m in ROW_RE.finditer(raw)
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", help="adb device serial (default: first device)")
    parser.add_argument("--count", type=int, default=100, help="messages to keep")
    parser.add_argument(
        "--out",
        default="app/test/fixtures/sample_inbox.json",
        help="output fixture path (default: %(default)s)",
    )
    args = parser.parse_args()

    serial = args.serial
    if not serial:
        devices = list_devices()
        if not devices:
            print("No adb devices found. Connect a phone with USB debugging on.",
                  file=sys.stderr)
            return 1
        serial = devices[0]

    print(f"Reading SMS inbox from {serial} ...")
    raw = run(["adb", "-s", serial, "shell", QUERY])
    rows = parse_rows(raw)
    inbox = sorted(
        (row for row in rows if row["type"] == 1),
        key=lambda row: row["date"],
        reverse=True,
    )
    selected = inbox[: args.count]
    if not selected:
        print("No inbox (type=1) messages returned.", file=sys.stderr)
        return 1

    device = serial
    try:
        device = run(["adb", "-s", serial, "shell", "getprop ro.product.model"]).strip() or serial
    except RuntimeError:
        pass

    payload = {
        "description": (
            f"{len(selected)} real Android SMS inbox messages captured "
            "for Budgetly test fixtures."
        ),
        "capturedAt": datetime.datetime.now(
            datetime.timezone.utc
        ).isoformat(timespec="seconds"),
        "device": device,
        "source": (
            "adb shell content query --uri content://sms/ "
            "--projection address:body:date:type (type=1 inbox)"
        ),
        "count": len(selected),
        "messages": [
            {
                "id": index + 1,
                "sender": row["sender"],
                "body": row["body"],
                "dateSent": row["date"],
            }
            for index, row in enumerate(selected)
        ],
    }

    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    newest = datetime.datetime.fromtimestamp(
        selected[0]["date"] / 1000, datetime.timezone.utc
    )
    oldest = datetime.datetime.fromtimestamp(
        selected[-1]["date"] / 1000, datetime.timezone.utc
    )
    print(
        f"Wrote {len(selected)} messages to {args.out} "
        f"(newest {newest.isoformat()}, oldest {oldest.isoformat()})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
