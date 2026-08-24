import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const ImportWalletScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 helper, field, and surface tokens', (tester) async {
    await pumpScreen(tester);

    final helper = tester.widget<Text>(find.textContaining('Restore an existing wallet'));
    expect(helper.style?.color, colors.textMuted);
    expect(helper.style?.fontSize, text.body.fontSize);

    expect(find.byType(QuantusTextField), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, colors.textContent);
    expect(field.style?.fontSize, text.dataAddressLarge.fontSize);
    expect(field.cursorColor, colors.accentFlare);
    expect(field.decoration?.hintStyle?.color, colors.textMuted);
    expect(field.maxLines, isNull);
    expect(field.expands, isTrue);

    final fieldBox = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color == colors.bgSurface);
    expect(fieldBox.borderRadius, radius.mdBorder);
    expect((fieldBox.border as Border?)?.top.color, colors.borderEmphasis);

    final eye = tester.widget<Icon>(find.byIcon(Icons.visibility_off_outlined));
    expect(eye.color, colors.textContent);
  });

  testWidgets('uses v3 ember caption for validation errors', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'one two three');
    await tester.pump();
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final error = tester.widget<Text>(find.text('Recovery phrase must be 12 or 24 words'));
    expect(error.style?.color, colors.semanticEmber);
    expect(error.style?.fontSize, text.caption.fontSize);
  });
}
