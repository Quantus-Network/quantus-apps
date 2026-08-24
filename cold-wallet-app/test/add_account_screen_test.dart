import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/add_account_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  Future<void> pumpScreen(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const AddAccountScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('derivation path uses QuantusTextField v3 tokens', (tester) async {
    await pumpScreen(tester);

    final helper = tester.widget<Text>(find.textContaining('Every account comes from the same recovery phrase'));
    expect(helper.style?.color, colors.textMuted);
    expect(helper.style?.fontSize, text.body.fontSize);

    final indexField = tester.widget<TextField>(find.byType(TextField));
    expect(indexField.style?.color, colors.textContent);
    expect(indexField.style?.fontSize, text.titleScreen.fontSize);
    expect(indexField.cursorColor, colors.accentFlare);

    await tester.tap(find.text('Derivation path'));
    await tester.pump();

    expect(find.byType(QuantusTextField), findsOneWidget);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.color, colors.textContent);
    expect(field.style?.fontSize, text.dataAddressLarge.fontSize);
    expect(field.style?.fontFamily, text.dataAddressLarge.fontFamily);
    expect(field.cursorColor, colors.accentFlare);
    expect(field.decoration?.hintStyle?.color, colors.textMuted);
    expect(field.maxLines, isNull);

    final fieldBox = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color == colors.bgSurface && (d.border as Border?)?.top.color == colors.borderEmphasis);
    expect(fieldBox.borderRadius, radius.mdBorder);
  });
}
