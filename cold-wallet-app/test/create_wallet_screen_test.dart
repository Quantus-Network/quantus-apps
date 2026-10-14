import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  testWidgets('shows the phrase under "New Key" with one way forward', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const CreateWalletScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('New Key'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Save your recovery phrase'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);

    final body = tester.widget<Text>(find.textContaining('Write these words down in order'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);

    expect(tester.widget<MnemonicGrid>(find.byType(MnemonicGrid)).isRevealed, isTrue);
    expect(find.text('ADVANCED'), findsOneWidget);
    expect(find.byType(QuantusButton), findsOneWidget);
    expect(find.text("I've written it down"), findsOneWidget);
  });
}
