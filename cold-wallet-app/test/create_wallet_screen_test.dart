import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/create_wallet_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  testWidgets('uses v3 body tokens for recovery-phrase instructions', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const CreateWalletScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final body = tester.widget<Text>(find.textContaining('Write these words down in order'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);
  });
}
