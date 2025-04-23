
# echo "Activating rename dart package"
# flutter pub global activate rename

echo "Setting app name"
rename setAppName --targets ios,android --value "Resonance Wallet"

echo "Setting bundle id"
rename setBundleId --targets android --value "io.resonancenetwork.wallet"  