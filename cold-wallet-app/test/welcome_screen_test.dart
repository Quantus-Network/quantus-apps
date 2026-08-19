import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/welcome_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  testWidgets('uses v3 hero title and muted body tokens', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        child: Builder(
          builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const WelcomeScreen()),
        ),
      ),
    );
    await tester.pump();

    final title = tester.widget<Text>(find.text('Quantus Cold Wallet'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleHero.fontSize);
    expect(title.style?.fontWeight, text.titleHero.fontWeight);

    final body = tester.widget<Text>(find.textContaining('An air-gapped signer'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);
  });
}
