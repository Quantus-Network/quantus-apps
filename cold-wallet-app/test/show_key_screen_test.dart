import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/show_key_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();
  const address = '5FakeSs58AddressForTests';
  const checkphrase = 'amber glacier quartz';

  Future<void> pumpShowKey(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addressProvider.overrideWith((ref) => address),
          checkphraseProvider.overrideWith((ref) async => checkphrase),
        ],
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const ShowKeyScreen()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('uses v3 helper, lilac checkphrase, and address tokens', (tester) async {
    await pumpShowKey(tester);

    final helper = tester.widget<Text>(find.textContaining('Scan with your Quantus hot wallet'));
    expect(helper.style?.color, colors.textMuted);
    expect(helper.style?.fontSize, text.body.fontSize);

    final phrase = tester.widget<Text>(find.text(checkphrase));
    expect(phrase.style?.color, colors.semanticLilac);
    expect(phrase.style?.fontSize, text.headingRow.fontSize);
    expect(phrase.style?.fontWeight, text.headingRow.fontWeight);

    final addressText = tester.widget<Text>(find.text(address));
    expect(addressText.style?.color, colors.textContent);
    expect(addressText.style?.fontSize, text.dataAddressLarge.fontSize);
    expect(addressText.style?.fontFamily, text.dataAddressLarge.fontFamily);

    final box = tester.widget<Container>(find.ancestor(of: find.text(address), matching: find.byType(Container)).first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface);
    expect(decoration.borderRadius, radius.mdBorder);
  });
}
