#!/bin/sh
# Checks a signed wallet APK against the app sources it was built from:
# signer certificate, package name, version and 16 KB alignment.
# Usage: verify_android_apk.sh <apk> <app-dir>
# Needs apksigner, aapt2 and zipalign (Android build-tools 35+) and openssl on PATH.
set -eu

[ $# -eq 2 ] || { echo "usage: $0 <apk> <app-dir>" >&2; exit 2; }
APK=$1
APP_DIR=$2

fail() { echo "error: $*" >&2; exit 1; }

for tool in apksigner aapt2 zipalign openssl; do
  command -v "$tool" >/dev/null || fail "$tool not found on PATH"
done
[ -f "$APK" ] || fail "APK not found: $APK"

sha256() { openssl dgst -sha256 -r | cut -d' ' -f1; }

EXPECTED_CERT=$(openssl x509 -in "$APP_DIR/android/upload_certificate.pem" -outform der | sha256)
EXPECTED_PACKAGE=$(sed -n 's/^[[:space:]]*applicationId[[:space:]=]*"\([^"]*\)".*/\1/p' "$APP_DIR"/android/app/build.gradle*)
EXPECTED_VERSION=$(sed -n 's/^version:[[:space:]]*//p' "$APP_DIR/pubspec.yaml")
[ -n "$EXPECTED_PACKAGE" ] || fail "no applicationId in $APP_DIR/android/app/build.gradle*"
[ -n "$EXPECTED_VERSION" ] || fail "no version in $APP_DIR/pubspec.yaml"

SIG=$(apksigner verify --verbose --print-certs "$APK" 2>&1) || { echo "$SIG" >&2; fail "apksigner rejects the signature of $APK"; }
echo "$SIG" | grep -qx 'Number of signers: 1' || fail "expected exactly one signer"
echo "$SIG" | grep -qE '^Verified using v(2|3) scheme .*: true$' || fail "no v2 or v3 signature"
CERT=$(echo "$SIG" | sed -n 's/^Signer #1 certificate SHA-256 digest: //p')
[ "$CERT" = "$EXPECTED_CERT" ] || fail "signer certificate $CERT does not match $APP_DIR/android/upload_certificate.pem ($EXPECTED_CERT)"

BADGING=$(aapt2 dump badging "$APK" | sed -n "s/^package: name='\([^']*\)' versionCode='\([^']*\)' versionName='\([^']*\)'.*/\1 \3+\2/p")
[ "$BADGING" = "$EXPECTED_PACKAGE $EXPECTED_VERSION" ] || fail "APK is '$BADGING', sources say '$EXPECTED_PACKAGE $EXPECTED_VERSION'"

zipalign -c -P 16 4 "$APK" >/dev/null || fail "APK is not zip-aligned for 16 KB pages"

echo "apk_sha256=$(sha256 < "$APK")"
echo "certificate_sha256=$CERT"
echo "package=$EXPECTED_PACKAGE"
echo "version=$EXPECTED_VERSION"
