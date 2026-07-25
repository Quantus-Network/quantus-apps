#!/usr/bin/env bash
#
# Run Patrol E2E tests on a physical iOS device.
#
# Why this script exists:
#   `patrol test` hardcodes `-destination-timeout 1` when launching the tests
#   (patrol_cli 4.4.0). A physical device that is still "connecting" (cold, or
#   just woken/unlocked) cannot become an eligible xcodebuild destination within
#   1 second, so it is reported as "Device is busy" and xcodebuild exits with
#   code 70. patrol's own build step (~60-90s) almost always lets the device go
#   cold, so plain `patrol test` is unreliable on real devices.
#
#   This script builds with patrol, then launches the tests itself with a
#   generous `-destination-timeout`, which tolerates the device reconnecting.
#
# Note: the *other* device issue (the app under test crashing at launch because
#   `_Testing_Foundation.framework` / `lib_TestingInterop.dylib` are not embedded
#   on Xcode 26.4+) is fixed permanently by the "Embed Swift Testing Frameworks
#   (device)" build phase in ios/Runner.xcodeproj, so it is NOT handled here.
#
# Usage:
#   scripts/patrol_ios_device.sh [options] [test_target ...]
#
# Options:
#   -d, --device <udid>   Target device UDID (default: first connected device).
#
# Test targets:
#   * Pass zero targets to run the WHOLE suite: patrol bundles every
#     `*_test.dart` under `patrol_test/` into a single app binary.
#   * Pass one or more targets to run only those files.
#
# Examples:
#   # Run all e2e tests on the first connected device:
#   scripts/patrol_ios_device.sh
#
#   # Run a single test:
#   scripts/patrol_ios_device.sh patrol_test/smoke/hello_world_test.dart
#
#   # Run a couple of tests on a specific device:
#   scripts/patrol_ios_device.sh -d 00008110-000848190E61401E \
#     patrol_test/flows/create_wallet_test.dart \
#     patrol_test/flows/import_wallet_test.dart
#
# Notes:
#   * Keep the iPhone unlocked and connected via USB while running.
#   * Run from anywhere; paths are resolved relative to this script.

# Note: intentionally not using `pipefail`. A step pipes into `head`, which
# closes the pipe early and would otherwise raise SIGPIPE (exit 141) and abort
# the whole script under `set -e`.
set -eu

# shellcheck source=lib/patrol_common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/patrol_common.sh"

usage() {
  echo "Usage: patrol_ios_device.sh [-d <device_udid>] [test_target ...]" >&2
}

patrol_ios_device_platform_option() {
  case "$1" in
    -d|--device)
      DEVICE_UDID="${2:?--device requires a UDID}"
      PLATFORM_CONSUMED=2
      return 0
      ;;
  esac
  return 1
}

DEVICE_UDID=""
patrol_parse_runner_args usage false patrol_ios_device_platform_option "$@"

# Tunables (override via environment if needed).
DESTINATION_TIMEOUT="${DESTINATION_TIMEOUT:-120}"
TEST_SERVER_PORT="${PATROL_TEST_SERVER_PORT:-8081}"
APP_SERVER_PORT="${PATROL_APP_SERVER_PORT:-8082}"

patrol_resolve_app_root "${BASH_SOURCE[0]}"

# Pick the device automatically if none was provided.
if [[ -z "$DEVICE_UDID" ]]; then
  DEVICE_UDID="$(idevice_id -l 2>/dev/null | head -1 || true)"
  if [[ -z "$DEVICE_UDID" ]]; then
    echo "ERROR: No iOS device found. Connect a device or pass its UDID." >&2
    exit 1
  fi
  echo "==> Auto-selected device: $DEVICE_UDID"
fi

patrol_collect_dart_defines
patrol_build_target_args building

echo "==> [1/3] Building Patrol bundle for device (release)..."
patrol build ios ${TARGET_ARGS[@]+"${TARGET_ARGS[@]}"} --release \
  ${DART_DEFINES[@]+"${DART_DEFINES[@]}"}

APP="build/ios_integ/Build/Products/Release-iphoneos/Runner.app"
if [[ ! -d "$APP" ]]; then
  echo "ERROR: Built app not found at $APP" >&2
  exit 1
fi

echo "==> [2/3] Locating .xctestrun..."
XCTESTRUN="$(ls -t build/ios_integ/Build/Products/Runner_iphoneos*.xctestrun | head -1)"
echo "    $XCTESTRUN"

echo "==> [3/3] Launching tests (destination-timeout=${DESTINATION_TIMEOUT}s)..."
RESULT_BUNDLE="build/ios_results_$(date +%s).xcresult"
cd ios
TEST_RUNNER_PATROL_TEST_PORT="$TEST_SERVER_PORT" \
TEST_RUNNER_PATROL_APP_PORT="$APP_SERVER_PORT" \
xcodebuild test-without-building \
  -xctestrun "../$XCTESTRUN" \
  -only-testing RunnerUITests/RunnerUITests \
  -destination "platform=iOS,id=$DEVICE_UDID" \
  -destination-timeout "$DESTINATION_TIMEOUT" \
  -resultBundlePath "../$RESULT_BUNDLE"

echo "==> Done. Result bundle: $RESULT_BUNDLE"
