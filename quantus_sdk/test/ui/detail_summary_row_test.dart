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

  testWidgets('stacked checkphrase is a second labeled row in lilac', (tester) async {
    await pumpRow(
      tester,
      const DetailSummaryRow.stacked(label: 'To', value: 'qzDest', monospace: true, checkphrase: 'alpha bravo'),
    );

    expect(find.text('TO'), findsOneWidget);
    expect(find.text('TO CHECKPHRASE'), findsOneWidget);
    final phrase = tester.widget<Text>(find.text('alpha bravo'));
    expect(phrase.style?.color, colors.semanticLilac);
    expect(phrase.style?.fontSize, text.dataAddressLarge.fontSize);
  });

  testWidgets('compact checkphrase sits under the value without a second label', (tester) async {
    await pumpRow(
      tester,
      const DetailSummaryRow(label: 'Destination', value: 'qzDest', monospace: true, checkphrase: 'alpha bravo'),
    );

    expect(find.text('DESTINATION CHECKPHRASE'), findsNothing);
    expect(find.text('Destination checkphrase'), findsNothing);
    final phrase = tester.widget<Text>(find.text('alpha bravo'));
    expect(phrase.style?.color, colors.semanticLilac);
    expect(phrase.style?.fontSize, text.caption.fontSize);
    expect(phrase.textAlign, TextAlign.right);

    final value = tester.widget<Text>(find.text('qzDest'));
    expect(value.style?.fontFamily, AppTextTheme.fontFamilySecondary);
    expect(value.textAlign, TextAlign.right);
  });

  testWidgets('compact shows a note under the row', (tester) async {
    await pumpRow(
      tester,
      const DetailSummaryRow(label: 'Amount', value: '99 raw', note: 'Asset decimals are not in this payload.'),
    );

    expect(find.text('Asset decimals are not in this payload.'), findsOneWidget);
  });
}
