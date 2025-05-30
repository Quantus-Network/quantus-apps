
# echo "Activating rename dart package"
# flutter pub global activate rename

echo "Setting app name"
rename setAppName --targets ios,android --value "Quantus Wallet"

echo "Setting bundle id"
rename setBundleId --targets ios,android --value "io.resonancenetwork.wallet"  