// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String greeting(String name) {
    return 'Halo, $name!';
  }

  @override
  String get authUseDeviceBiometricsToUnlock => 'Gunakan biometrik untuk membuka perangkat';

  @override
  String get authAuthenticating => 'Mengotentikasi...';

  @override
  String get authUnlockWallet => 'Buka Wallet';

  @override
  String get authAuthorizationRequired => 'Otorisasi \n Diperlukan';
}
