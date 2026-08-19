import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/connectivity_provider.dart';
import 'package:quantus_cold_wallet/screens/home_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  Future<void> pumpHome(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [isOnlineProvider.overrideWith((ref) => false)],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const HomeScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 intro, card, and icon tokens', (tester) async {
    await pumpHome(tester);

    final intro = tester.widget<Text>(find.textContaining('Choose an action'));
    expect(intro.style?.color, colors.textMuted);
    expect(intro.style?.fontSize, text.body.fontSize);

    final title = tester.widget<Text>(find.text('Show Key'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.headingRow.fontSize);
    expect(title.style?.fontWeight, text.headingRow.fontWeight);

    final subtitle = tester.widget<Text>(find.textContaining('Display your public address'));
    expect(subtitle.style?.color, colors.textMuted);
    expect(subtitle.style?.fontSize, text.caption.fontSize);

    final actionIcon = tester.widget<Icon>(find.byIcon(Icons.qr_code_2_rounded));
    expect(actionIcon.color, colors.accentFlare);

    final card = tester.widget<Container>(
      find.ancestor(of: find.text('Show Key'), matching: find.byType(Container)).first,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface);
    expect(decoration.borderRadius, radius.mdBorder);
    expect((decoration.border as Border?)?.top.color, colors.borderHairline);

    expect(tester.widget<Icon>(find.byIcon(Icons.lock_outline)).color, colors.textContent);
    expect(tester.widget<Icon>(find.byIcon(Icons.settings_outlined)).color, colors.textContent);
  });
}
