#!/usr/bin/env bash
#
# Run Patrol E2E tests on an Android emulator.
#
# Android counterpart of scripts/patrol_ios_device.sh, scoped to emulators for
# local E2E runs. Unlike iOS physical devices, `patrol test` can build and run
# in one step on Android without the xcodebuild destination-timeout workaround.
#
# Usage:
#   scripts/patrol_android_emulator.sh [options] [test_target ...]
#
# Options:
#   -d, --device <serial>   Emulator serial (default: first running emulator).
#   -a, --avd <name>        Start this AVD when no emulator is running.
#       --debug             Build a debug binary (default).
#       --release           Build a release binary.
#
# Environment:
#   ANDROID_EMULATOR_AVD    Default AVD to boot when none is running and -a
#                           is not passed (falls back to the first listed AVD).
#   EMULATOR_BOOT_TIMEOUT   Seconds to wait for boot (default: 120).
#
# Test targets:
#   * Pass zero targets to run the WHOLE suite: patrol bundles every
#     `*_test.dart` under `patrol_test/` into a single app binary.
#   * Pass one or more targets to run only those files.
#
# Examples:
#   # Run all e2e tests on the first running emulator:
#   scripts/patrol_android_emulator.sh
#
#   # Boot a specific AVD, then run tests:
#   scripts/patrol_android_emulator.sh -a Pixel_8_API_35
#
#   # Run a single test:
#   scripts/patrol_android_emulator.sh patrol_test/smoke/hello_world_test.dart
#
# Notes:
#   * Start an emulator in Android Studio, or pass -a / set ANDROID_EMULATOR_AVD.
#   * Run from anywhere; paths are resolved relative to this script.

# Note: intentionally not using `pipefail`. A step pipes into `head`, which
# closes the pipe early and would otherwise raise SIGPIPE (exit 141) and abort
# the whole script under `set -e`.
set -eu

# shellcheck source=lib/patrol_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/patrol_common.sh"

usage() {
  echo "Usage: patrol_android_emulator.sh [-d <serial>] [-a <avd>] [--debug|--release] [test_target ...]" >&2
}

patrol_android_emulator_platform_option() {
  case "$1" in
    -d|--device)
      DEVICE_SERIAL="${2:?--device requires a serial}"
      PLATFORM_CONSUMED=2
      return 0
      ;;
    -a|--avd)
      AVD_NAME="${2:?--avd requires a name}"
      PLATFORM_CONSUMED=2
      return 0
      ;;
  esac
  return 1
}

first_running_emulator() {
  adb devices 2>/dev/null | awk '$2 == "device" && $1 ~ /^emulator-/ {print $1; exit}'
}

first_listed_avd() {
  if ! command -v emulator >/dev/null 2>&1; then
    return 1
  fi
  emulator -list-avds 2>/dev/null | head -1
}

wait_for_emulator_boot() {
  local serial="$1"
  local timeout="${EMULATOR_BOOT_TIMEOUT:-120}"
  echo "==> Waiting for $serial to finish booting (timeout ${timeout}s)..."
  adb -s "$serial" wait-for-device
  local start
  start="$(date +%s)"
  while true; do
    local boot_completed
    boot_completed="$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
    if [[ "$boot_completed" == "1" ]]; then
      echo "==> Emulator ready: $serial"
      return 0
    fi
    if (( $(date +%s) - start > timeout )); then
      echo "ERROR: Emulator $serial did not boot within ${timeout}s." >&2
      exit 1
    fi
    sleep 2
  done
}

start_emulator() {
  local avd_name="$1"
  if ! command -v emulator >/dev/null 2>&1; then
    echo "ERROR: \`emulator\` not found. Install the Android SDK emulator or" \
         "start an AVD from Android Studio." >&2
    exit 1
  fi

  echo "==> Starting emulator: $avd_name"
  emulator -avd "$avd_name" -no-snapshot-load >/dev/null 2>&1 &
  local start
  start="$(date +%s)"
  local timeout="${EMULATOR_BOOT_TIMEOUT:-120}"
  while true; do
    local serial
    serial="$(first_running_emulator || true)"
    if [[ -n "$serial" ]]; then
      DEVICE_SERIAL="$serial"
      return 0
    fi
    if (( $(date +%s) - start > timeout )); then
      echo "ERROR: Emulator process started but no serial appeared within ${timeout}s." >&2
      exit 1
    fi
    sleep 2
  done
}

DEVICE_SERIAL=""
AVD_NAME=""
patrol_parse_runner_args usage true patrol_android_emulator_platform_option "$@"

patrol_resolve_app_root "${BASH_SOURCE[0]}"

# Pick or boot an emulator.
if [[ -z "$DEVICE_SERIAL" ]]; then
  DEVICE_SERIAL="$(first_running_emulator || true)"
  if [[ -n "$DEVICE_SERIAL" ]]; then
    echo "==> Auto-selected running emulator: $DEVICE_SERIAL"
  fi
fi

if [[ -z "$DEVICE_SERIAL" ]]; then
  if [[ -z "$AVD_NAME" ]]; then
    AVD_NAME="${ANDROID_EMULATOR_AVD:-$(first_listed_avd || true)}"
  fi
  if [[ -z "$AVD_NAME" ]]; then
    echo "ERROR: No running emulator found and no AVD to boot." >&2
    echo "       Start one in Android Studio, pass -a <avd>, or set ANDROID_EMULATOR_AVD." >&2
    exit 1
  fi
  start_emulator "$AVD_NAME"
fi

wait_for_emulator_boot "$DEVICE_SERIAL"

if [[ "$DEVICE_SERIAL" != emulator-* ]]; then
  echo "WARNING: $DEVICE_SERIAL does not look like an emulator serial." >&2
fi

patrol_collect_dart_defines
patrol_build_target_args running

echo "==> Running Patrol tests on $DEVICE_SERIAL ($BUILD_MODE)..."
patrol test \
  --device "$DEVICE_SERIAL" \
  "$BUILD_MODE" \
  ${TARGET_ARGS[@]+"${TARGET_ARGS[@]}"} \
  ${DART_DEFINES[@]+"${DART_DEFINES[@]}"}

echo "==> Done."
