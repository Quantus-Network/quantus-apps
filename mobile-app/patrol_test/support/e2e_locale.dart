import 'dart:io';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/app_locale.dart';

/// Resolves locale settings for E2E tests to match the running app.
class E2eLocale {
  E2eLocale._();

  /// Same rules as [SelectedAppLocaleNotifier]: saved preference, else OS language.
  static LocaleNumberConfig numberConfig() {
    final code =
        SettingsService().getSelectedAppLocale() ?? Platform.localeName.split('_').first.toLowerCase();
    final appLocale = AppLocale.fromCode(code);
    return LocaleNumberConfig.fromLocale(appLocale.numberFormatLocale);
  }
}
