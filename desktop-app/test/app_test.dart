import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/bootstrap/app_bootstrap.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_pane.dart';
import 'package:quantus_desktop_wallet/ui/shell/sidebar.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';

import 'fakes.dart';

void main() {
  testWidgets("the app is titled Quantus Wallet, uses the dark theme and offers wallet_core's locales", (tester) async {
    await tester.pumpWidget(buildApp(overrides: shellOverrides()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Quantus Wallet');
    expect(app.themeMode, ThemeMode.dark);
    expect(app.supportedLocales, AppLocalizations.supportedLocales);
    expect(app.localizationsDelegates, AppLocalizations.localizationsDelegates);
  });

  testWidgets('the app uses the desktop type scale and the language chosen in settings', (tester) async {
    await tester.pumpWidget(buildApp(overrides: shellOverrides()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.extension<AppTextThemeV3>(), same(const AppTextThemeV3.desktop()));
    expect(app.locale, const Locale('en'));
  });

  testOnMac('the app opens on the shell: a sidebar beside the account pane', (tester) async {
    await pumpShell(tester, overrides: shellOverrides());

    expect(find.byType(Sidebar), findsOneWidget);
    expect(find.byType(AccountPane), findsOneWidget);
    expect(tester.getTopLeft(find.byType(Sidebar)).dx, lessThan(tester.getTopLeft(find.byType(AccountPane)).dx));
  });
}
