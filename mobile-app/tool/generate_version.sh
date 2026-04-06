#!/bin/sh
cd "$(dirname "$0")/.."
LINE=$(grep '^version:' pubspec.yaml)
RAW=$(echo "$LINE" | sed 's/version: *//')
VER=$(echo "$RAW" | cut -d'+' -f1)
BUILD=$(echo "$RAW" | cut -d'+' -f2)
mkdir -p lib/generated
printf "const appVersion = '%s';\nconst appBuildNumber = '%s';\n" "$VER" "$BUILD" > lib/generated/version.g.dart
