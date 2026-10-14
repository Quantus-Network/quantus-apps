import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/offline_pill.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/screens/home_screen.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/account_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHome(WidgetTester tester, {required bool online}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...accountOverrides([one, two]),
          isOnlineProvider.overrideWith((ref) => online),
        ],
        child: coldApp(const HomeScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('offline: ready to sign, with the offline pill and the scan button', (tester) async {
    await pumpHome(tester, online: false);

    expect(find.text('Ready to sign'), findsOneWidget);
    expect(find.text('Offline. Nothing can reach this device.'), findsOneWidget);
    expect(find.byType(OfflinePill), findsOneWidget);
    expect(tester.widget<QuantusIcon>(quantusIcon(QuantusIcons.wifiSlash).first).color, coldColors.semanticSage);
    expect(find.widgetWithText(QuantusButton, 'Scan Transaction'), findsOneWidget);
    expect(find.textContaining('re-lock'), findsNothing);
    expect(quantusIcon(QuantusIcons.lock), findsNothing);

    final title = tester.widget<Text>(find.text('Ready to sign'));
    expect(title.style?.fontSize, const AppTextThemeV3.standard().titleHero.fontSize);
    expect(title.style?.color, coldColors.textContent);
  });

  testWidgets('online with the override: not safe to sign, no pill', (tester) async {
    await pumpHome(tester, online: true);

    expect(find.text('Not Safe to Sign'), findsOneWidget);
    expect(find.text('You overrode the network lock. Switch your connections off.'), findsOneWidget);
    expect(find.byType(OfflinePill), findsNothing);
    expect(tester.widget<QuantusIcon>(quantusIcon(QuantusIcons.wifiSlash)).color, coldColors.semanticEmber);
    expect(find.widgetWithText(QuantusButton, 'Scan Transaction'), findsOneWidget);
  });

  testWidgets('the gear opens Settings', (tester) async {
    await pumpHome(tester, online: false);

    await tester.tap(quantusIcon(QuantusIcons.gear));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
  });
}
