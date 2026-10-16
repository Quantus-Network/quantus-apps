import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes/wallet_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpSettings(WidgetTester tester, {bool canProtect = true}) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [coldAuthServiceProvider.overrideWithValue(FakeColdAuth(canProtect: canProtect))],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('uses section, row and switch tokens with no password row', (tester) async {
    await pumpSettings(tester);

    for (final label in ['SECURITY', 'SIGNATURE QR', 'DANGER ZONE']) {
      final widget = tester.widget<Text>(find.text(label));
      expect(widget.style?.color, colors.textMuted);
      expect(widget.style?.fontSize, text.labelMonogram.fontSize);
      expect(widget.style?.fontFamily, text.labelMonogram.fontFamily);
    }

    expect(find.text('Change password'), findsNothing);

    final rowTitle = tester.widget<Text>(find.text('Show secret phrase'));
    expect(rowTitle.style?.color, colors.textContent);
    expect(rowTitle.style?.fontSize, text.headingRow.fontSize);

    final helper = tester.widget<Text>(find.textContaining('Reveal the recovery phrase'));
    expect(helper.style?.color, colors.textMuted);
    expect(helper.style?.fontSize, text.caption.fontSize);

    final reset = tester.widget<Text>(find.text('Reset wallet'));
    expect(reset.style?.color, colors.semanticEmber);
    expect(reset.style?.fontSize, text.headingRow.fontSize);

    final wifiSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(wifiSwitch.activeTrackColor, colors.accentFlare);
  });

  testWidgets('describes the unlock method from the device lock', (tester) async {
    await pumpSettings(tester);
    expect(find.text('Unlock method'), findsOneWidget);
    expect(find.textContaining('Face ID or passcode.'), findsOneWidget);

    await pumpSettings(tester, canProtect: false);
    expect(find.textContaining('None. This phone has no device lock'), findsOneWidget);
  });

  testWidgets('reset asks before wiping', (tester) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.text('Reset wallet'));
    await tester.tap(find.text('Reset wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Reset wallet?'), findsOneWidget);
    expect(find.textContaining('You can only restore the key with your recovery phrase.'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
  });
}
