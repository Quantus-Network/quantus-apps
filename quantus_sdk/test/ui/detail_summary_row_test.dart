import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> pumpRow(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: row),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('uses v3 muted label and content value tokens', (tester) async {
    await pumpRow(tester, const DetailSummaryRow(label: 'Network fee', value: '1.00 QNT'));

    final label = tester.widget<Text>(find.text('Network fee'));
    expect(label.style?.color, colors.textMuted);
    expect(label.style?.fontSize, 10);
    expect(label.style?.letterSpacing, 1);
    expect(label.style?.fontFamily, AppTextTheme.fontFamilySecondary);

    final value = tester.widget<Text>(find.text('1.00 QNT'));
    expect(value.style?.color, colors.textContent);
    expect(value.style?.fontSize, text.body.fontSize);
    expect(value.textAlign, TextAlign.right);
  });

  testWidgets('stacked uppercases the label and paints a wrapping value', (tester) async {
    await pumpRow(tester, const DetailSummaryRow.stacked(label: 'Genesis hash', value: '0xabc', monospace: true));

    expect(find.text('GENESIS HASH'), findsOneWidget);
    expect(find.text('Genesis hash'), findsNothing);

    final value = tester.widget<Text>(find.text('0xabc'));
    expect(value.textAlign, isNull);
    expect(value.style?.fontFamily, AppTextTheme.fontFamilySecondary);
    expect(value.style?.fontSize, text.dataAddressLarge.fontSize);
    expect(value.style?.color, colors.textContent);
  });

  testWidgets('stacked applies valueColor and shows a note', (tester) async {
    await pumpRow(
      tester,
      DetailSummaryRow.stacked(
        label: 'Signing as checkphrase',
        value: 'alpha bravo',
        valueColor: colors.semanticLilac,
        note: 'Verify out loud.',
      ),
    );

    final value = tester.widget<Text>(find.text('alpha bravo'));
    expect(value.style?.color, colors.semanticLilac);
    expect(find.text('Verify out loud.'), findsOneWidget);
  });
}
