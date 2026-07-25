#!/bin/sh

## Build, install and launch the app on a physical iOS device entirely from the
## command line (no Xcode app), streaming the device console to this terminal.
##
## This is because Flutter and XCode have massive problems running on a connected device
## in iOS 26. If they ever fix it, we can probably delete this.
##
## Uses profile mode by default. Pass "release" to override.
##
## Usage: ./run_on_device.sh [profile|release]

set -eu

MODE="${1:-profile}"

if [ "$MODE" = "debug" ]; then
  echo "ERROR: debug builds cannot run standalone on iOS (FlutterEngine aborts" >&2
  echo "       without a debugger). Use 'profile' or 'release', or 'flutter run'." >&2
  exit 1
fi

if [ "$MODE" != "profile" ] && [ "$MODE" != "release" ]; then
  echo "ERROR: unknown mode '$MODE' (expected 'profile' or 'release')" >&2
  exit 1
fi

APP="build/ios/iphoneos/Runner.app"
DEVS_JSON="$(mktemp)"
trap 'rm -f "$DEVS_JSON"' EXIT

echo "==> Detecting connected iOS device"
xcrun devicectl list devices --json-output "$DEVS_JSON" >/dev/null
DEVICE_ID="$(jq -r '
  [.result.devices[]
   | select(.hardwareProperties.platform == "iOS")
   | select(.connectionProperties.tunnelState == "connected")
   | .identifier][0] // empty' "$DEVS_JSON")"

if [ -z "$DEVICE_ID" ]; then
  echo "ERROR: no connected iOS device found. Plug in and unlock the device." >&2
  exit 1
fi
DEVICE_NAME="$(jq -r --arg id "$DEVICE_ID" '
  .result.devices[] | select(.identifier == $id) | .deviceProperties.name' "$DEVS_JSON")"
echo "    device: $DEVICE_NAME ($DEVICE_ID)"

echo "==> Building $MODE"
flutter build ios "--$MODE"

BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
if [ -z "$BUNDLE_ID" ]; then
  echo "ERROR: could not read CFBundleIdentifier from $APP/Info.plist" >&2
  exit 1
fi

echo "==> Installing $BUNDLE_ID"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"

echo "==> Launching (console attached — Ctrl-C to detach)"
exec xcrun devicectl device process launch \
  --console \
  --terminate-existing \
  --device "$DEVICE_ID" \
  "$BUNDLE_ID"
