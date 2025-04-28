#!/bin/sh

## archive and upload the app to ios App store

flutter build ipa --release
open -a "Transporter" "build/ios/ipa/Quantus Wallet.ipa"
