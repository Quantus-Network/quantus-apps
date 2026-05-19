import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/app_locale.dart';
/// Persists and exposes the user's chosen app locale.
/// Defaults to [AppLocale.en] when no preference has been saved.
///
/// To change the active locale (e.g. from a settings screen):
///   ref.read(selectedAppLocaleProvider.notifier).select(AppLocale.id);
final selectedAppLocaleProvider =
    StateNotifierProvider<SelectedAppLocaleNotifier, AppLocale>((ref) {
  return SelectedAppLocaleNotifier(SettingsService());
});

class SelectedAppLocaleNotifier extends StateNotifier<AppLocale> {
  final SettingsService _settings;

  SelectedAppLocaleNotifier(this._settings) : super(_load(_settings));

  Future<void> select(AppLocale locale) async {
    await _settings.setSelectedAppLocale(locale.languageCode);
    state = locale;
  }

  static AppLocale _load(SettingsService settings) {
    final code = settings.getSelectedAppLocale();
    if (code == null) return AppLocale.en;
    return AppLocale.fromCode(code);
  }
}

final localeProvider = Provider<Locale>((ref) {
  return ref.watch(selectedAppLocaleProvider).flutterLocale;
});

final l10nProvider = Provider<AppLocalizations>((ref) {
  return lookupAppLocalizations(ref.watch(localeProvider));
});
