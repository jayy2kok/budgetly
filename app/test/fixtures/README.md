# Real SMS inbox sample fixture

`sample_inbox.json` holds **100 real Android SMS inbox messages** (the 100 most
recent, captured newest-first) used as deterministic sample data for app tests
and for seeding a mobile emulator during manual testing.

| Field       | Meaning                                                        |
|-------------|----------------------------------------------------------------|
| `id`        | Fixture row id (1 = newest). Used as the SMS `_id` in tests.   |
| `sender`    | SMS address / bank sender ID (e.g. `JD-INDUSB-S`, `HDFCBK`).    |
| `body`      | Full raw SMS body.                                             |
| `dateSent`  | Receive timestamp, epoch milliseconds (UTC).                   |

Provenance is recorded in the JSON (`device`, `source`, `capturedAt`). The data
is intentionally unscrubbed; it is a personal test fixture for this project.

## Using it in tests

```dart
import '../fixtures/sample_inbox.dart';
import '../helpers/inbox_fakes.dart';

final inbox = loadSampleInbox();       // typed rows + metadata
stubSmsInbox(inbox.toSmsMessages());   // feed SmsQuery's method channel
```

See `test/services/sms_inbox_reader_sample_test.dart` for the suite that runs
`SmsInboxReader` over the whole fixture.

The reader stops after `ApiConfig.smsSyncMaxMessages` financial messages
(default **10**). To exercise all 79 financial-looking samples, run with:

```bash
flutter run --dart-define=SMS_SYNC_MAX_MESSAGES=100
```

## Refreshing the fixture

Requires a USB/wireless-debugging Android phone with `adb` access:

```bash
python scripts/sms_samples/pull_inbox.py --count 100 \
    --out app/test/fixtures/sample_inbox.json
```

`pull_inbox.py` uses `content query` (this device build rejects `--limit`, so it
filters/sorts in Python), keeps `type=1` (inbox) rows only, and handles bodies
containing newlines.

## Seeding an emulator for manual testing

Start an Android emulator, then:

```bash
python scripts/sms_samples/seed_emulator.py \
    --fixture app/test/fixtures/sample_inbox.json
```

This pushes the fixture rows into the emulator's SMS inbox with
`adb emu sms send`, so the app's normal `SmsInboxReader` path reads them like
real messages. It requires an emulator (the emulator console); it will refuse to
run against a physical device.

## One command: launch emulator → wait → clean → load messages → start the app

`scripts/sms_samples/run_app_with_samples.sh` does the full manual-testing
sequence in a single step — launch the selected AVD, wait until `sys.boot_completed`,
seed the fixture, and run the app:

```bash
bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a
```

**Every run is a clean start by default.** The script relaunches the AVD with
`-wipe-data`, so the app is installed fresh and the inbox is empty before the
samples are loaded. (The AVD images here are `user` builds whose SMS provider
silently refuses `content delete`, so a data wipe is the only reliable empty
inbox.) On first launch after the fresh install, accept the app's on-screen SMS
permission prompt.

Useful flags:

```bash
# Choose how many of the 100 samples to load (seeds N messages AND sets the
# app's SMS_SYNC_MAX_MESSAGES cap to N):
bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a --max-messages 25

# Keep the existing AVD state: reuse a running emulator, no wipe, no reset:
bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a --no-clean

# Don't open a window (CI / headless runs) and stop before starting the app:
bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a --headless --no-app

# Load messages only, using an emulator you started yourself:
bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a --no-launch --no-seed --no-app

# Pass extra dart-defines through to flutter run:
bash scripts/sms_samples/run_app_with_samples.sh -- --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Run `bash scripts/sms_samples/run_app_with_samples.sh --help` for the full list.
The default `--max-messages` is 100 so all sample rows are ingested.
