// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get walletInitErrorTitle => 'Wallet Error';

  @override
  String get walletInitErrorMessage => 'Unable to find secret phrase. Please restore your wallet.';

  @override
  String get walletInitErrorButtonLabel => 'OK';

  @override
  String get authUseDeviceBiometricsToUnlock => 'Use device biometrics to unlock';

  @override
  String get authAuthenticating => 'Authenticating...';

  @override
  String get authUnlockWallet => 'Unlock Wallet';

  @override
  String get authAuthorizationRequired => 'Authorization \n Required';
}
