#!/bin/sh

## archive and upload the app to ios App store

echo "Cleaning build folder"
rm -rf build/ios/ipa/*.ipa

echo "Building the app"
flutter build ipa --release

echo "Opening Transporter"
open -a "Transporter" "build/ios/ipa/Quantus.ipa"
