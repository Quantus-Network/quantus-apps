import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  testWidgets('uses v3 warning icon, title, and body tokens', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const SecureElementWarningScreen()),
      ),
    );
    await tester.pump();

    final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
    expect(icon.color, colors.semanticSand);

    final title = tester.widget<Text>(find.text('No secure element detected'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);
    expect(title.style?.fontWeight, text.titleScreen.fontWeight);

    final body = tester.widget<Text>(find.textContaining('This device has no biometrics'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);
  });
}
