import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';

/// Strings for the app's locale. `ref.watch` in build, `ref.read` in callbacks.
final l10nProvider = Provider<AppLocalizations>((ref) => lookupAppLocalizations(const Locale('en')));
