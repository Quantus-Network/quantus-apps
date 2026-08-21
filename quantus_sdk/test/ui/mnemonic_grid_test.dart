import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  testWidgets('uses v3 surface, muted index, and lilac word tokens', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: const Scaffold(body: MnemonicGrid(words: ['abandon', 'ability', 'able'], isRevealed: true)),
          ),
        ),
      ),
    );
    await tester.pump();

    final index = tester.widget<Text>(find.text('1'));
    expect(index.style?.color, colors.textMuted);
    expect(index.style?.fontSize, text.caption.fontSize);

    final word = tester.widget<Text>(find.text('abandon'));
    expect(word.style?.color, colors.semanticLilac);
    expect(word.style?.fontSize, text.caption.fontSize);

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('abandon'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface);
    expect(decoration.borderRadius, radius.mdBorder);
  });
}
