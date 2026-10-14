import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/offline_pill.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_cold_wallet/screens/welcome_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpWelcome(WidgetTester tester, {bool online = false}) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWithValue(online)],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const WelcomeScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses the hero title, muted body and the offline pill', (tester) async {
    await pumpWelcome(tester);

    final title = tester.widget<Text>(find.text('Quantus Cold Wallet'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleHero.fontSize);
    expect(title.style?.fontWeight, text.titleHero.fontWeight);

    final body = tester.widget<Text>(find.textContaining('Your keys stay on this device.'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.bodyLarge.fontSize);

    expect(find.byType(OfflinePill), findsOneWidget);
    expect(find.text('Create New Key'), findsOneWidget);
    expect(find.text('Import Key'), findsOneWidget);
    expect(find.byType(QuantusIcon), findsWidgets);
  });

  testWidgets('hides the offline pill while online', (tester) async {
    await pumpWelcome(tester, online: true);
    expect(find.byType(OfflinePill), findsNothing);
  });

  testWidgets('Create New Key opens the recovery phrase step', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Create New Key'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateWalletScreen), findsOneWidget);
  });

  testWidgets('Import Key opens the import step', (tester) async {
    await pumpWelcome(tester);

    await tester.tap(find.text('Import Key'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportWalletScreen), findsOneWidget);
  });
}
