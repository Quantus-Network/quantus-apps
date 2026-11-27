#!/bin/bash

## Archive the macOS app for the Mac App Store (TestFlight) and open the
## package in Transporter to upload it.
##
##   ./upload_macos_build.sh --testnet
##   ./upload_macos_build.sh --mainnet
##
## The version and build number are pubspec.yaml's (`version: 0.1.0+2` is
## version 0.1.0, build 2): raise the build number before every upload, as App
## Store Connect refuses one it has seen.
##
## Signing is Xcode's, as for the phone: sign into Xcode (Settings › Accounts)
## with an Apple account on team 8BRRAHLVW5 that may distribute, and Xcode
## picks or makes the certificates and the provisioning profile.

set -euo pipefail

cd "$(dirname "$0")"

ARCHIVE="build/macos/Quantus Wallet.xcarchive"
EXPORT="build/macos/app-store"

fail() { echo "Error: $*" >&2; exit 1; }

# The network is always named: a build without RUN_ON_TESTNET is on mainnet.
NETWORK=""
for arg in "$@"; do
  case "$arg" in
    --testnet | --mainnet)
      [ -z "$NETWORK" ] || fail "Give --testnet or --mainnet once."
      NETWORK="${arg#--}"
      ;;
    *) fail "Unknown option: $arg" ;;
  esac
done
[ -n "$NETWORK" ] || fail "Say which network the build is for: --testnet or --mainnet."

# What is uploaded must be a commit that can be found again.
git diff --quiet HEAD || fail "There are uncommitted changes. Commit or stash them first."
COMMIT=$(git rev-parse --short HEAD)

[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' macos/Runner/Release.entitlements)" = "true" ] \
  || fail "macos/Runner/Release.entitlements is not sandboxed; the Mac App Store takes only sandboxed apps."

VERSION=$(sed -n 's/^version: //p' pubspec.yaml)
echo "Archiving $VERSION on $NETWORK from $COMMIT"

flutter pub get --enforce-lockfile
# Leftovers of earlier builds must not end up in the package.
rm -rf build/macos

# Writes pubspec.yaml's version and the network into Xcode's settings; the
# archive below then builds the Flutter part with them.
DEFINES=()
[ "$NETWORK" = "testnet" ] && DEFINES+=(--dart-define=RUN_ON_TESTNET=true)
flutter build macos --release --config-only "${DEFINES[@]+"${DEFINES[@]}"}"

xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner -configuration Release \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist macos/ExportOptions.plist -allowProvisioningUpdates

PKGS=("$EXPORT"/*.pkg)
[ ${#PKGS[@]} -eq 1 ] && [ -f "${PKGS[0]}" ] || fail "Expected one package in $EXPORT; found: $(ls "$EXPORT")"
PKG="${PKGS[0]}"
echo "Built $PKG: Quantus Wallet $VERSION, $NETWORK, commit $COMMIT."
echo "Opening Transporter"
open -a "Transporter" "$PKG"
