import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart'; // Import your generated file

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

final l10nProvider = Provider<AppLocalizations>((ref) {
  final locale = ref.watch(localeProvider); 
  
  return lookupAppLocalizations(locale); 
});