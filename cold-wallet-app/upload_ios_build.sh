#!/bin/sh

## archive and upload the app to ios App store

set -eu

# Ensure Xcode export uses Apple's rsync implementation.
# In case user installed custom rsync in homebrew for example
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo "Cleaning build folder"
rm -rf build/ios/ipa/*.ipa

# Clean because sometimes there's fragments of compile items left that get uploaded
# to the app store and cause the entire upload to fail...
echo "Flutter clean"
flutter clean

echo "Building the app"
flutter build ipa --release

# The IPA name comes from the Xcode product name (Runner.ipa for this project);
# glob it instead of hardcoding so a rename doesn't silently break the script.
ipa_path=$(ls build/ios/ipa/*.ipa | head -n 1)

echo "Opening Transporter"
open -a "Transporter" "$ipa_path"
