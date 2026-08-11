#!/bin/sh

## archive and upload the app to ios App store

set -eu

# Ensure Xcode export uses Apple's rsync implementation.
# In case user installed custom rsync in homebrew for example
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Faster than `flutter clean` (avoids Flutter tool startup and keeps .dart_tool).
# Needed because leftover compile fragments can get packaged into the IPA and fail App Store upload.
echo "Cleaning build folder"
rm -rf build

echo "Building the app"
flutter build ipa --release

echo "Opening Transporter"
open -a "Transporter" "build/ios/ipa/Quantus.ipa"