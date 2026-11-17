#!/usr/bin/env bash
#
# Launch an Android emulator, wait until it has finished booting, seed the
# Budgetly sample SMS inbox, then start the Flutter app on it.
#
# By default every run is a clean start: the app is freshly reinstalled and the
# emulator inbox is emptied before the chosen number of sample messages is loaded.
# Pass --no-clean to keep the current app install and inbox.
#
# Snapshot AVDs (Pixel_9a_jayraj, Pixel_9a_jayy2kok) carry a pre-logged-in Google
# account in a `logged_in_base` snapshot. Pass --snapshot <name> (or nothing: the
# AVD's own configured snapshot is picked up automatically) to boot from it. The
# data wipe is then skipped so the login survives, and -no-snapshot-save keeps the
# snapshot untouched -- every run starts fresh with no messages but the Google
# account already signed in.
#
# Usage (from the repo root, or anywhere if you use an absolute path):
#   bash scripts/sms_samples/run_app_with_samples.sh [options] [-- flutter args]
#
# Options:
#   --avd NAME          AVD to launch (default: $BUDGETLY_AVD, else first AVD)
#   --snapshot NAME     Boot from this emulator snapshot (default: the AVD's
#                       configured snapshot, e.g. logged_in_base; else none).
#                       Skips -wipe-data so a logged-in Google account survives.
#   --gpu MODE          Emulator -gpu value (snapshot-mode default:
#                       swiftshader_indirect; otherwise left to the emulator).
#   --serial SERIAL     Use an already-running device/emulator
#   --fixture PATH      Sample inbox JSON (default: app/test/fixtures/sample_inbox.json)
#   --max-messages N    Sample messages to load and the app's sync cap (default: 100)
#   --api-base URL      API_BASE_URL dart-define
#   --headless          Launch the emulator without a window
#   --no-app            Seed messages only; do not start the app
#   --no-seed           Skip seeding (useful with --no-clean; avoids duplicates)
#   --no-clean          Keep existing app install + inbox instead of a clean start
#   --no-launch         Do not launch an emulator; use one that is running
#   --timeout SECONDS   Boot/launch timeout (default: 300)
#   --stop-on-exit      Kill the emulator when this script/flutter run exits
#   -h, --help          Show this help
#
# Anything after `--` is forwarded to `flutter run`, e.g.
#   ... -- --dart-define=LOG_LEVEL=debug
#
# Examples:
#   bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a
#   bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a_jayraj
#   bash scripts/sms_samples/run_app_with_samples.sh --avd Pixel_9a_jayy2kok --snapshot logged_in_base
#   bash scripts/sms_samples/run_app_with_samples.sh --headless --no-app
#
set -euo pipefail

APP_ID="com.budgetly.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="$REPO_ROOT/app"

AVD="${BUDGETLY_AVD:-}"
SNAPSHOT=""
GPU_MODE=""
SERIAL_EXPLICIT=""
FIXTURE="$REPO_ROOT/app/test/fixtures/sample_inbox.json"
MAX_MESSAGES=100
API_BASE=""
HEADLESS=false
NO_APP=false
NO_SEED=false
NO_LAUNCH=false
NO_CLEAN=false
TIMEOUT=300
STOP_ON_EXIT=false
PASSTHRU=()

info() { printf '\033[1;34m[budgetly]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[budgetly]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[budgetly]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  awk '
    NR == 1 { next }
    /^#/    { line = $0; sub(/^# ?/, "", line); print line; next }
    { exit }
  ' "${BASH_SOURCE[0]}"
}

while (( $# )); do
  case "$1" in
    --avd)          AVD="${2:?--avd needs a value}"; shift 2 ;;
    --snapshot)     SNAPSHOT="${2:?--snapshot needs a value}"; shift 2 ;;
    --gpu)          GPU_MODE="${2:?--gpu needs a value}"; shift 2 ;;
    --serial)       SERIAL_EXPLICIT="${2:?--serial needs a value}"; shift 2 ;;
    --fixture)      FIXTURE="${2:?--fixture needs a value}"; shift 2 ;;
    --max-messages) MAX_MESSAGES="${2:?--max-messages needs a value}"; shift 2 ;;
    --api-base)     API_BASE="${2:?--api-base needs a value}"; shift 2 ;;
    --headless)     HEADLESS=true; shift ;;
    --no-app)       NO_APP=true; shift ;;
    --no-seed)      NO_SEED=true; shift ;;
    --no-clean)     NO_CLEAN=true; shift ;;
    --no-launch)    NO_LAUNCH=true; shift ;;
    --timeout)      TIMEOUT="${2:?--timeout needs a value}"; shift 2 ;;
    --stop-on-exit) STOP_ON_EXIT=true; shift ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; PASSTHRU=("$@"); break ;;
    *)              die "Unknown option: $1 (use -- to pass arguments to flutter run)" ;;
  esac
done

[[ "$MAX_MESSAGES" =~ ^[0-9]+$ ]] || die "--max-messages must be a non-negative integer (got '$MAX_MESSAGES')."

# ── Toolchain resolution ────────────────────────────────────────────────

is_windows() {
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

# Git Bash on this machine omits these Windows vars, which Flutter's native
# toolchain needs. Batch files can't be exported from bash, so pass them to
# the child process via `env`.
FLUTTER_ENV=()
if is_windows; then
  FLUTTER_ENV+=("ProgramFiles=C:\\Program Files")
  FLUTTER_ENV+=("ProgramFiles(x86)=C:\\Program Files (x86)")
  FLUTTER_ENV+=("ProgramData=C:\\ProgramData")
  FLUTTER_ENV+=("SystemRoot=C:\\Windows")
fi

run_flutter() {
  if (( ${#FLUTTER_ENV[@]} )); then
    env "${FLUTTER_ENV[@]}" flutter "$@"
  else
    flutter "$@"
  fi
}

unixify() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s' "$1"; fi
}

ADB="${ADB:-adb}"
if ! command -v "$ADB" >/dev/null 2>&1; then
  for candidate in \
    "${LOCALAPPDATA:+$(unixify "$LOCALAPPDATA")/Android/Sdk/platform-tools/adb.exe}" \
    "${ANDROID_HOME:+$(unixify "${ANDROID_HOME:-}")/platform-tools/adb}" \
    "${ANDROID_SDK_ROOT:+$(unixify "${ANDROID_SDK_ROOT:-}")/platform-tools/adb}" \
    "$HOME/Android/Sdk/platform-tools/adb"; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then ADB="$candidate"; break; fi
  done
fi
command -v "$ADB" >/dev/null 2>&1 || die "adb not found. Add Android platform-tools to PATH."

find_emulator_bin() {
  local candidates=()
  [ -n "${ANDROID_HOME:-}" ]     && candidates+=("$(unixify "$ANDROID_HOME")/emulator/emulator")
  [ -n "${ANDROID_SDK_ROOT:-}" ] && candidates+=("$(unixify "$ANDROID_SDK_ROOT")/emulator/emulator")
  if [ -n "${LOCALAPPDATA:-}" ]; then
    candidates+=("$(unixify "$LOCALAPPDATA")/Android/Sdk/emulator/emulator.exe")
  fi
  candidates+=("$HOME/Android/Sdk/emulator/emulator")
  local candidate
  for candidate in "${candidates[@]}"; do
    if [ -x "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  done
  return 1
}

resolve_python() {
  local candidate
  for candidate in "${PYTHON:-}" python3 python; do
    [ -n "$candidate" ] || continue
    if "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[0] == 3 else 1)' \
        >/dev/null 2>&1; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

# ── Emulator selection / launch ─────────────────────────────────────────

list_emulator_serials() {
  # Only emulators whose adb link is already usable (state == "device").
  "$ADB" devices 2>/dev/null | awk -F'[\t ]+' '/^emulator-[0-9]+/ && $2 == "device" { print $1 }'
}

list_any_emulator_serials() {
  # Any emulator line, including "offline" ones still coming up.
  "$ADB" devices 2>/dev/null | awk -F'[\t ]+' '/^emulator-[0-9]+/ { print $1 }'
}

pick_avd() {
  if [ -n "$AVD" ]; then printf '%s' "$AVD"; return 0; fi
  local output
  output="$(run_flutter emulators 2>/dev/null || true)"
  printf '%s\n' "$output" | awk -F'•' '
    {
      id = $1
      gsub(/^[ \t\r]+|[ \t\r]+$/, "", id)
      if (id != "" && id != "Id" && id !~ /available emulators/) { print id; exit }
    }'
}

avd_config_ini() {
  # Path to $AVD.avd/config.ini, or nothing if the AVD is not on this machine.
  local avd_home ini
  if [ -n "${ANDROID_AVD_HOME:-}" ]; then
    avd_home="$ANDROID_AVD_HOME"
  elif [ -n "${ANDROID_PREFS_ROOT:-}" ]; then
    avd_home="$ANDROID_PREFS_ROOT/avd"
  elif [ -n "${ANDROID_SDK_HOME:-}" ]; then
    avd_home="$ANDROID_SDK_HOME/.android/avd"
  else
    avd_home="$HOME/.android/avd"
  fi
  ini="$avd_home/$1.avd/config.ini"
  if [ -f "$ini" ]; then printf '%s' "$ini"; return 0; fi
  return 1
}

avd_configured_snapshot() {
  # If this AVD is configured to always boot from a snapshot
  # (fastboot.forceChosenSnapshotBoot=yes + fastboot.chosenSnapshotFile=<name>),
  # print that name. The snapshot AVDs Pixel_9a_jayraj / Pixel_9a_jayy2kok pin
  # `logged_in_base` here, so `--avd Pixel_9a_jayraj` alone already restores the
  # pre-logged-in Google account without needing --snapshot on the command line.
  local ini force file
  ini="$(avd_config_ini "$1")" || return 0
  force="$(sed -n 's/^fastboot\.forceChosenSnapshotBoot=//p' "$ini" | tr -d '\r')"
  file="$(sed -n 's/^fastboot\.chosenSnapshotFile=//p' "$ini" | tr -d '\r')"
  if [ "$force" = "yes" ] && [ -n "$file" ]; then printf '%s' "$file"; fi
}

avd_snapshot_exists() {
  # True if a snapshot of this name exists on disk for the given AVD.
  local ini snap
  ini="$(avd_config_ini "$1")" || return 1
  snap="$(dirname "$ini")/snapshots/$2"
  [ -d "$snap" ]
}

SERIAL=""
cleanup() {
  if [ "$STOP_ON_EXIT" = true ] && [ -n "${SERIAL:-}" ]; then
    info "Stopping emulator $SERIAL ..."
    "$ADB" -s "$SERIAL" emu kill >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ -n "$SERIAL_EXPLICIT" ]; then
  SERIAL="$SERIAL_EXPLICIT"
  info "Using device $SERIAL (launch skipped)."
elif [ "$NO_LAUNCH" = true ]; then
  SERIAL="$(list_emulator_serials | head -n 1)"
  [ -n "$SERIAL" ] || die "--no-launch given but no emulator is running."
  info "Using running emulator $SERIAL."
else
  AVD="$(pick_avd)"
  [ -n "$AVD" ] || die "No AVD selected. Pass --avd <name> or create one with 'flutter emulators --create'."

  # If no snapshot was named, boot whatever snapshot the AVD itself is
  # configured for (fastboot.forceChosenSnapshotBoot=yes). The snapshot AVDs
  # Pixel_9a_jayraj / Pixel_9a_jayy2kok pin `logged_in_base` here, so
  # `--avd Pixel_9a_jayraj` alone already restores the pre-logged-in Google
  # account. An explicit --snapshot always wins.
  if [ -z "$SNAPSHOT" ]; then
    configured="$(avd_configured_snapshot "$AVD")"
    if [ -n "$configured" ]; then
      SNAPSHOT="$configured"
      info "AVD '$AVD' is configured to boot from snapshot '$configured'."
    fi
  fi

  # If an emulator already running this AVD is up, reuse it -- unless a clean
  # start is requested, in which case it must be relaunched so its data can be
  # wiped (a running instance can't be wiped).
  for running_serial in $(list_emulator_serials); do
    if "$ADB" -s "$running_serial" emu avd name 2>/dev/null | grep -qi "$AVD"; then
      if [ "$NO_CLEAN" = true ]; then
        SERIAL="$running_serial"
        info "AVD '$AVD' is already running as $SERIAL; reusing it."
      else
        if [ -n "$SNAPSHOT" ]; then
          info "Clean start: stopping already-running $AVD ($running_serial) so it can relaunch from snapshot '$SNAPSHOT'."
        else
          info "Clean start: stopping already-running $AVD ($running_serial) so it can relaunch wiped."
        fi
        "$ADB" -s "$running_serial" emu kill >/dev/null 2>&1 || true
        sleep 3  # let the old instance deregister from adb before re-detecting
      fi
      break
    fi
  done

  if [ -z "$SERIAL" ]; then
    EMULATOR_BIN="$(find_emulator_bin)" || die "Could not find the emulator binary."
    BEFORE="$(list_any_emulator_serials || true)"
    EXTRA_EMU_ARGS=""
    if [ "$HEADLESS" = true ]; then
      EXTRA_EMU_ARGS="-no-window -no-audio -no-boot-anim"
    fi

    if [ -n "$SNAPSHOT" ]; then
      # Boot from a named snapshot (e.g. logged_in_base) so the Google account is
      # already signed in. Skip -wipe-data: wiping the data partition would erase
      # that login. Keep -no-snapshot-save so the base snapshot is never
      # overwritten -- every run starts from the same pristine, logged-in state.
      if [ -z "$GPU_MODE" ]; then GPU_MODE="swiftshader_indirect"; fi
      if [ -n "$GPU_MODE" ]; then EXTRA_EMU_ARGS="$EXTRA_EMU_ARGS -gpu $GPU_MODE"; fi
      EXTRA_EMU_ARGS="$EXTRA_EMU_ARGS -snapshot $SNAPSHOT -no-snapshot-save"
      info "Launching emulator '$AVD' from snapshot '$SNAPSHOT' (Google login preserved; no -wipe-data)."
      if ! avd_snapshot_exists "$AVD" "$SNAPSHOT"; then
        warn "Snapshot '$SNAPSHOT' not found for AVD '$AVD'; the emulator will cold-boot instead (no Google login)."
      fi
    elif [ "$HEADLESS" = true ]; then
      info "Launching emulator '$AVD' (headless, fresh boot) ..."
      EXTRA_EMU_ARGS="$EXTRA_EMU_ARGS -no-snapshot"
    else
      info "Launching emulator '$AVD' (windowed, fresh boot) ..."
      # Launch directly so we can disable snapshot restore/save: a restored
      # snapshot is what leaves an emulator wedged at "offline" in adb.
      EXTRA_EMU_ARGS="$EXTRA_EMU_ARGS -no-snapshot-load -no-snapshot-save"
    fi
    if [ "$NO_CLEAN" != true ] && [ -z "$SNAPSHOT" ]; then
      # The telephony provider on this AVD's user build refuses content delete,
      # so -wipe-data is the only reliable way to empty the inbox (and it also
      # gives the app a genuinely fresh install).
      EXTRA_EMU_ARGS="$EXTRA_EMU_ARGS -wipe-data"
      info "Clean start: AVD data will be wiped (-wipe-data)."
    elif [ -n "$SNAPSHOT" ] && [ "$NO_CLEAN" != true ]; then
      info "Clean start: AVD data is NOT wiped (snapshot '$SNAPSHOT' restored instead)."
    fi
    "$EMULATOR_BIN" -avd "$AVD" $EXTRA_EMU_ARGS \
      >"${TMPDIR:-/tmp}/budgetly-emulator.log" 2>&1 &

    DEADLINE=$((SECONDS + TIMEOUT))
    while (( SECONDS < DEADLINE )); do
      for candidate in $(list_any_emulator_serials); do
        if ! printf '%s\n' "$BEFORE" | grep -qx "$candidate"; then
          SERIAL="$candidate"
          break 2
        fi
      done
      sleep 2
    done

    if [ -z "$SERIAL" ]; then
      SERIAL="$(list_any_emulator_serials | head -n 1)"
    fi
    [ -n "$SERIAL" ] || die "Emulator did not appear within ${TIMEOUT}s (log: ${TMPDIR:-/tmp}/budgetly-emulator.log)."
    info "Emulator is $SERIAL."
  fi
fi

# ── Wait for boot ───────────────────────────────────────────────────────

info "Waiting for $SERIAL to come online and finish booting (timeout ${TIMEOUT}s) ..."
BOOTED=""
DEADLINE=$((SECONDS + TIMEOUT))
while (( SECONDS < DEADLINE )); do
  BOOTED="$("$ADB" -s "$SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)"
  if [ "$BOOTED" = "1" ]; then break; fi
  sleep 2
done
[ "$BOOTED" = "1" ] || die "Timed out waiting for $SERIAL to boot."
sleep 2
info "Boot complete."

# ── Clean start (default) ───────────────────────────────────────────────

if [ "$NO_CLEAN" = true ]; then
  info "Keeping existing app install and inbox (--no-clean)."
else
  info "Clean start: ensuring $APP_ID is uninstalled and the inbox is empty ..."
  # Fresh install: remove the app so `flutter run` installs it from scratch.
  "$ADB" -s "$SERIAL" uninstall "$APP_ID" >/dev/null 2>&1 || true
  # Empty the SMS provider so each run seeds exactly MAX_MESSAGES, never more.
  "$ADB" -s "$SERIAL" shell content delete --uri content://sms/ >/dev/null 2>&1 \
    || "$ADB" -s "$SERIAL" shell content delete --uri content://sms/ --where "_id > 0" >/dev/null 2>&1 \
    || true
  remaining="$("$ADB" -s "$SERIAL" shell content query --uri content://sms/ --projection _id 2>/dev/null | grep -c '^Row:' || true)"
  if [ "${remaining:-0}" -ne 0 ]; then
    warn "Inbox not fully cleared ($remaining row(s) remain); seeded messages may duplicate."
  fi
fi

# ── Load sample messages ────────────────────────────────────────────────

if [ "$NO_SEED" = true ]; then
  info "Skipping message seeding (--no-seed)."
else
  [ -f "$FIXTURE" ] || die "Fixture not found: $FIXTURE"
  PYTHON_BIN="$(resolve_python)" || die "python3 not found (needed to seed messages)."
  info "Loading ${MAX_MESSAGES} message(s) from ${FIXTURE#"$REPO_ROOT"/} ..."
  "$PYTHON_BIN" "$SCRIPT_DIR/seed_emulator.py" \
    --fixture "$FIXTURE" --serial "$SERIAL" --limit "$MAX_MESSAGES"
fi

# Best-effort: auto-grant SMS permissions if the app is already installed.
# A clean start uninstalled it, so `flutter run` reinstalls and the app asks
# for SMS access on screen -- accept the prompt there.
if "$ADB" -s "$SERIAL" shell pm path "$APP_ID" >/dev/null 2>&1; then
  "$ADB" -s "$SERIAL" shell pm grant "$APP_ID" android.permission.READ_SMS \
    >/dev/null 2>&1 || true
  "$ADB" -s "$SERIAL" shell pm grant "$APP_ID" android.permission.RECEIVE_SMS \
    >/dev/null 2>&1 || true
  info "SMS permissions granted to $APP_ID."
fi

# ── Start the app ───────────────────────────────────────────────────────

if [ "$NO_APP" = true ]; then
  info "Messages loaded; skipping app start (--no-app)."
  exit 0
fi

DART_DEFINES=(--dart-define="SMS_SYNC_MAX_MESSAGES=$MAX_MESSAGES")
if [ -n "$API_BASE" ]; then
  DART_DEFINES+=(--dart-define="API_BASE_URL=$API_BASE")
fi

info "Starting the app on $SERIAL (sync cap $MAX_MESSAGES) ..."
cd "$APP_DIR"
if (( ${#PASSTHRU[@]} )); then
  run_flutter run -d "$SERIAL" "${DART_DEFINES[@]}" "${PASSTHRU[@]}"
else
  run_flutter run -d "$SERIAL" "${DART_DEFINES[@]}"
fi
