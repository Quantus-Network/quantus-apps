#!/usr/bin/env bash
# Checks every package's formatting as CI does, analyzes every package, then
# runs the mobile suite, and prints only what failed and a verdict. The whole
# output goes to check.log at the root.
#
#   melos run check
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
log="$root/check.log"
mobile_log="$root/check-mobile.log"
format_log="$root/check-format.log"
trap 'rm -f "$mobile_log" "$format_log"' EXIT

echo "Checking $(git rev-parse --short HEAD) on $(git branch --show-current)" | tee "$log"

echo "Checking formatting..."
# CI's own check, reporting only: nothing is rewritten.
melos exec --concurrency=1 -- "dart format lib test --line-length=120 --set-exit-if-changed --output=none" \
  >"$format_log" 2>&1
format=$?
cat "$format_log" >>"$log"
if [ "$format" -eq 0 ]; then
  echo "format: passed"
else
  echo "format: FAILED (melos run format fixes it)"
  # Each file that would change, after the package it is in.
  awk '/^[a-z_]+:$/ { package = $0 } /Changed / { sub(/^ +/, ""); print "  " package " " $0 }' "$format_log"
fi

echo "Analyzing all packages..."
melos exec --concurrency=1 -- "flutter analyze . --fatal-infos" >>"$log" 2>&1
analyze=$?
if [ "$analyze" -eq 0 ]; then
  echo "analyze: passed"
else
  echo "analyze: FAILED"
  # Each issue, after the package it is in.
  awk '/^[a-z_]+:$/ { package = $0 } / • / { sub(/^ +/, ""); print "  " package " " $0 }' "$log"
fi

echo "Running the mobile suite..."
(cd mobile-app && flutter test --no-pub --reporter=failures-only) >"$mobile_log" 2>&1
mobile=$?
cat "$mobile_log" >>"$log"
if [ "$mobile" -eq 0 ]; then
  echo "mobile tests: passed ($(grep -oE '\+[0-9]+' "$mobile_log" | tail -1 | tr -d +) tests)"
else
  echo "mobile tests: FAILED"
  tail -60 "$mobile_log"
fi

if [ "$format" -eq 0 ] && [ "$analyze" -eq 0 ] && [ "$mobile" -eq 0 ]; then
  echo "CHECK PASSED"
else
  echo "CHECK FAILED (full output: check.log)"
  exit 1
fi
