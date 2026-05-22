/// App locale persistence and localized strings via Riverpod.
///
/// ## App strings (canonical)
///
/// Use [l10nProvider] for all user-facing copy. Do **not** use
/// `AppLocalizations.of(context)` in widgets.
///
/// - **`ref.watch(l10nProvider)`** — in `build` (or anywhere the UI must
///   rebuild when the user changes language).
/// - **`ref.read(l10nProvider)`** — one-off access in callbacks, timers, or
///   `try/catch` handlers where a subscription is wrong or wasteful. Capture
///   localized strings early if a callback can outlive a locale change.
///
/// ```dart
/// // build — rebuilds on locale change
/// final l10n = ref.watch(l10nProvider);
///
/// // callback — no subscription
/// onTap: () => context.showErrorToaster(
///   message: ref.read(l10nProvider).someError,
/// );
/// ```
///
/// ## Framework localization
///
/// [MaterialApp] in `app.dart` sets `locale`, `localizationsDelegates`, and
/// `supportedLocales` so Material/Cupertino built-ins (date pickers, etc.)
/// respect the active locale. App copy still comes from [l10nProvider].
///
/// ## Pure logic and tests
///
/// Pass [AppLocalizations] as a parameter, or call
/// `lookupAppLocalizations(const Locale('en'))` in unit tests.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/app_locale.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Persists and exposes the user's chosen app locale.
/// Defaults to [AppLocale.en] when no preference has been saved.
///
/// To change the active locale (e.g. from a settings screen):
///   ref.read(selectedAppLocaleProvider.notifier).select(AppLocale.id);
final selectedAppLocaleProvider = StateNotifierProvider<SelectedAppLocaleNotifier, AppLocale>((ref) {
  final settings = ref.watch(settingsServiceProvider);
  return SelectedAppLocaleNotifier(settings);
});

class SelectedAppLocaleNotifier extends StateNotifier<AppLocale> {
  final SettingsService _settings;

  static final String _defaultLocaleCode = Platform.localeName.split('_').first.toLowerCase();

  SelectedAppLocaleNotifier(this._settings) : super(_load(_settings));

  Future<void> select(AppLocale locale) async {
    await _settings.setSelectedAppLocale(locale.languageCode);
    state = locale;
  }

  Future<void> reset() async {
    await _settings.clearSelectedAppLocale();
    state = AppLocale.fromCode(_defaultLocaleCode);
  }

  static AppLocale _load(SettingsService settings) {
    String? code = settings.getSelectedAppLocale();
    code ??= _defaultLocaleCode;

    return AppLocale.fromCode(code);
  }
}

/// Localized strings for the active app locale.
final l10nProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(selectedAppLocaleProvider).flutterLocale;
  return lookupAppLocalizations(locale);
});
