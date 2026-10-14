import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/screens/import_wallet_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const ImportWalletScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  QuantusButton importButton(WidgetTester tester) =>
      tester.widget<QuantusButton>(find.widgetWithText(QuantusButton, 'Import Key'));

  testWidgets('uses the SDK phrase field, the derivation field and a disabled button until typed', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Import Key'), findsNWidgets(2));
    final helper = tester.widget<Text>(find.textContaining('Restore an existing key'));
    expect(helper.style?.color, colors.textMuted);
    expect(helper.style?.fontSize, text.body.fontSize);

    expect(find.byType(QuantusSeedPhraseField), findsOneWidget);
    expect(find.byType(DerivationField), findsOneWidget);
    expect(importButton(tester).isDisabled, isTrue);

    await tester.enterText(find.byType(TextField), 'one');
    await tester.pump(const Duration(milliseconds: 400));
    expect(importButton(tester).isDisabled, isFalse);
  });

  testWidgets('a phrase of the wrong length is refused inline', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'one two three');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(QuantusButton, 'Import Key'));
    await tester.pump();

    expect(find.text('Recovery phrase must be 12 or 24 words'), findsOneWidget);
  });
}
