#!/bin/sh

## archive and upload the app to ios App store

echo "Cleaning build folder"
rm -rf build/ios/ipa/*.ipa

# Clean because sometimes there's fragments of compile items left that get uploaded
# to the app store and cause the entire upload to fail... 
echo "Flutter clean"
flutter clean

echo "Building the app"
flutter build ipa --release

echo "Opening Transporter"
open -a "Transporter" "build/ios/ipa/Quantus.ipa"
