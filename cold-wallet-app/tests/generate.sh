#!/usr/bin/env bash
# Regenerates README.txt, the QR codes in qr/ and app-review.pdf from
# generate_review_qr.dart. Needs the SDK's Rust library, built once with
# quantus_sdk/test/build_library.sh, and Chrome or Brave to print the PDF.
set -euo pipefail
cd "$(dirname "$0")/.."

browser="${BROWSER:-}"
for candidate in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
	"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
	if [ -z "$browser" ] && [ -x "$candidate" ]; then browser="$candidate"; fi
done
if [ -z "$browser" ]; then
	echo "Neither Chrome nor Brave found; set BROWSER to a Chromium binary" >&2
	exit 69
fi

html="$(mktemp -d)/app-review.html"
FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR="$PWD/../quantus_sdk/rust/target/release/" REVIEW_HTML="$html" \
	flutter test tests/generate_review_qr.dart
"$browser" --headless --disable-gpu --no-pdf-header-footer --print-to-pdf="$PWD/tests/app-review.pdf" "file://$html"
