import 'package:flutter/material.dart';

/// App UI locales the user can select in settings.
enum AppLocale {
  en(languageCode: 'en', displayName: 'English', numberFormatLocale: 'en_US'),
  id(languageCode: 'id', displayName: 'Bahasa Indonesia', numberFormatLocale: 'id_ID');

  const AppLocale({required this.languageCode, required this.displayName, required this.numberFormatLocale});

  final String languageCode;
  final String displayName;
  final String numberFormatLocale;

  Locale get flutterLocale => Locale(languageCode);

  static AppLocale fromCode(String code, {AppLocale fallback = AppLocale.en}) {
    return AppLocale.values.firstWhere((l) => l.languageCode == code, orElse: () => fallback);
  }
}
