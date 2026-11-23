# Flutter integration (E2E) flows

On-device end-to-end tests for the Budgetly app. Each flow boots the real
widget tree (`BudgetlyApp` + GoRouter + Riverpod) with every network seam
replaced by an in-memory double, so a run needs **no backend, no Google
account, and no network**.

| File | Flow | What it proves |
|---|---|---|
| `app_test.dart` | Boot | Cold start renders the login screen with no error banner; a `/join?code=…` deep link opens the Join Family screen. |
| `auth_flow_test.dart` | Auth | A successful sign-in swaps the login gate for the four-tab shell and loads the user's family. |
| `expense_flow_test.dart` | Expense | FAB → Add Expense → Save posts one `EXPENSE` payload with the entered amount/merchant and the new row appears in the Feed; empty form is blocked by validation. |
| `sms_flow_test.dart` | SMS | A bank SMS read from the (stubbed) device inbox is parsed locally and auto-posted as `REGEX_LOCAL`; an OTP is excluded. |
| `helpers/integration_harness.dart` | — | Shared doubles, provider overrides, and `pumpIntegrationApp`. |

## Prerequisites

- Flutter SDK matching `app/pubspec.yaml`.
- An Android emulator or device. This repo's reference emulators are
  `Pixel_9a_jayraj` (primary) and `Pixel_9a_jayy2kok` (secondary).
- Fonts are bundled under `app/assets/google_fonts/`, so no font download
  happens at runtime.

## Run

```bash
cd app

# List/boot an emulator if none is attached
flutter emulators                      # or: flutter emulators --launch Pixel_9a_jayraj
adb devices                            # wait for "<serial>  device"

# Whole suite (serial = emulator serial, or "-d Pixel_9a_jayraj")
flutter test integration_test -d emulator-5554

# One flow
flutter test integration_test/sms_flow_test.dart -d emulator-5554
```

A passing run ends with `All tests passed!` and `+6` for the full suite
(2 boot + 1 auth + 2 expense + 1 SMS). The run rebuilds and installs a debug
APK first, so expect ~2 minutes on a cold emulator.

## How the flows stay hermetic

`pumpIntegrationApp` builds a `ProviderContainer` with overrides for
`authServiceProvider`, `transactionServiceProvider`, `categoryServiceProvider`,
`budgetServiceProvider`, `messageServiceProvider`, `patternCacheServiceProvider`,
`smsInboxReaderProvider`, plus seeded `authProvider`, `familyProvider`, and
`smsProvider` state. The app itself is not modified.

Two seams deserve a note:

- **Sign-in.** The Google account picker cannot run on an emulator, and the
  button calls the real `google_sign_in` plugin. The auth flow therefore drives
  the same entry point the button uses:
  `authProvider.notifier.signInWithGoogle(overrideIdToken: '<test-token>')`,
  and asserts the login screen's `ref.listen` redirect lands on the dashboard.
- **SMS.** The real `SmsInboxReader`/`SmsParserService`/`SmsNotifier` run, with
  three substitutions: the `flutter_sms_inbox` method channel returns a fixed
  message list (`plugins.juliusgithaiga.com/querySMS`, `JSONMethodCodec`), the
  OS permission layer is a fake that grants `Permission.sms`, and the pattern
  cache is seeded offline. `RecordingTransactionService` echoes each created
  payload back as a `Transaction`, so inbox pairing by `sourceRawText` is real.

Flows that do not exercise SMS also seed `SmsState(hasPromptedForConsent: true)`
and `SharedPreferences.setMockInitialValues({'sms_consent_prompted': true})` so
the dashboard's consent sheet cannot cover the UI under test.

`settleFor(tester)` pumps real time in 100 ms slices (then settles) because the
live integration binding stops settling as soon as no frame is queued, while
mock services use 100–500 ms `Future.delayed` round-trips.

## CI

`.github/workflows/ci.yml` intentionally does **not** run these flows: the
hosted `ubuntu-latest` runners have no nested virtualization, so an Android
emulator there is either impossible or unusably slow. Standard CI keeps gating
on `flutter analyze` + `flutter test` (`app/test/`).

To gate E2E in CI, add a dedicated job on a runner with KVM and a booted
device — for example a self-hosted Linux runner with
`reactivecircus/android-emulator-runner`:

```yaml
  app-e2e:
    runs-on: [self-hosted, linux, kvm]
    defaults:
      run:
        working-directory: app
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: "3.41.2"
          channel: stable
      - run: flutter pub get
      - uses: reactivecircus/android-emulator-runner@v2
        with:
          api-level: 34
          target: google_apis
          arch: x86_64
          working-directory: app
          script: flutter test integration_test -d emulator-5554
```
