import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/settings_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpSettings(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const SettingsScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 section, row, divider, and switch tokens', (tester) async {
    await pumpSettings(tester);

    for (final label in ['SECURITY', 'SIGNATURE QR', 'DANGER ZONE']) {
      final widget = tester.widget<Text>(find.text(label));
      expect(widget.style?.color, colors.textMuted);
      expect(widget.style?.fontSize, text.labelMonogram.fontSize);
      expect(widget.style?.fontFamily, text.labelMonogram.fontFamily);
    }

    final rowTitle = tester.widget<Text>(find.text('Change password'));
    expect(rowTitle.style?.color, colors.textContent);
    expect(rowTitle.style?.fontSize, text.body.fontSize);

    final helper = tester.widget<Text>(find.textContaining('Set or change the password'));
    expect(helper.style?.color, colors.textMuted);
    expect(helper.style?.fontSize, text.caption.fontSize);

    final reset = tester.widget<Text>(find.text('Reset wallet'));
    expect(reset.style?.color, colors.semanticEmber);
    expect(reset.style?.fontSize, text.body.fontSize);

    final dividers = tester.widgetList<Divider>(find.byType(Divider));
    expect(dividers, isNotEmpty);
    for (final divider in dividers) {
      expect(divider.color, colors.borderHairline);
    }

    final wifiSwitch = tester.widget<Switch>(find.byType(Switch));
    expect(wifiSwitch.activeTrackColor, colors.accentFlare);
  });
}
