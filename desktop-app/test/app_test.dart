import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

void main() {
  testWidgets("the app is titled Quantus Wallet, uses the dark theme and offers wallet_core's locales", (tester) async {
    await tester.pumpWidget(buildApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Quantus Wallet');
    expect(app.themeMode, ThemeMode.dark);
    expect(app.supportedLocales, AppLocalizations.supportedLocales);
    expect(app.localizationsDelegates, AppLocalizations.localizationsDelegates);
  });
}
