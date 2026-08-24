import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const words = ['abandon', 'ability', 'able'];

  Future<void> pumpGrid(
    WidgetTester tester, {
    required bool isRevealed,
    VoidCallback? onToggle,
    Key? hideHintKey,
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: MnemonicRevealGrid(
                words: words,
                isRevealed: isRevealed,
                revealHint: 'Tap to reveal',
                hideHint: 'Tap to hide',
                onToggle: onToggle ?? () {},
                hideHintKey: hideHintKey,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('blurs the grid and shows the reveal hint until revealed', (tester) async {
    await pumpGrid(tester, isRevealed: false);

    expect(find.text('Tap to reveal'), findsOneWidget);
    expect(find.text('Tap to hide'), findsNothing);
    expect(find.text('abandon'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    final hint = tester.widget<Text>(find.text('Tap to reveal'));
    expect(hint.style?.color, colors.textContent);
    expect(hint.style?.fontSize, text.body.fontSize);
  });

  testWidgets('shows words and the hide hint when revealed', (tester) async {
    const hideHintKey = Key('hide-hint');
    await pumpGrid(tester, isRevealed: true, hideHintKey: hideHintKey);

    expect(find.text('abandon'), findsOneWidget);
    expect(find.text('Tap to hide'), findsOneWidget);
    expect(find.text('Tap to reveal'), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byKey(hideHintKey), findsOneWidget);

    final hint = tester.widget<Text>(find.text('Tap to hide'));
    expect(hint.style?.color, colors.textMuted);
    expect(hint.style?.fontSize, text.body.fontSize);
  });

  testWidgets('tap notifies the parent so it can own reveal state', (tester) async {
    var toggled = false;
    await pumpGrid(tester, isRevealed: false, onToggle: () => toggled = true);

    await tester.tap(find.text('Tap to reveal'));
    await tester.pump();
    expect(toggled, isTrue);
  });
}
