
# echo "Activating rename dart package"
# flutter pub global activate rename

echo "Setting app name"
rename setAppName --targets ios,android --value "Quantus Wallet"

echo "Setting bundle id ios"
rename setBundleId --targets ios --value "com.quantus.mobile-wallet"  

echo "Setting bundle id Android"
rename setBundleId --targets android --value "com.quantus.wallet"