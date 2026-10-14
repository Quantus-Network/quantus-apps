import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpWarning(WidgetTester tester, void Function(bool?) onResult) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                onResult(
                  await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => const SecureElementWarningScreen()),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the missing lock and what it means', (tester) async {
    await pumpWarning(tester, (_) {});

    expect(find.byType(QuantusIcon), findsOneWidget);
    final title = tester.widget<Text>(find.text('No device lock'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleHero.fontSize);
    expect(title.style?.fontWeight, text.titleHero.fontWeight);

    final body = tester.widget<Text>(find.textContaining('stored without user presence'));
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.bodyLarge.fontSize);
  });

  testWidgets('Go back answers false, Continue anyway answers true', (tester) async {
    bool? result;
    await pumpWarning(tester, (r) => result = r);

    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue anyway'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
