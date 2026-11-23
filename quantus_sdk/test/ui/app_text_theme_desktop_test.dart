import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

Map<String, TextStyle> _stylesOf(AppTextThemeV3 theme) => {
  'displayCharge': theme.displayCharge,
  'displayBalance': theme.displayBalance,
  'titleSuccess': theme.titleSuccess,
  'titleHero': theme.titleHero,
  'amountHero': theme.amountHero,
  'titleScreen': theme.titleScreen,
  'amountInline': theme.amountInline,
  'amountRow': theme.amountRow,
  'headingRow': theme.headingRow,
  'bodyLarge': theme.bodyLarge,
  'bodyEmphasis': theme.bodyEmphasis,
  'body': theme.body,
  'caption': theme.caption,
  'labelChip': theme.labelChip,
  'dataAddress': theme.dataAddress,
  'dataAddressLarge': theme.dataAddressLarge,
  'labelData': theme.labelData,
  'labelMonogram': theme.labelMonogram,
};

Future<BuildContext> _pumpContext(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    Builder(
      builder: (c) {
        context = c;
        return const SizedBox();
      },
    ),
  );
  return context;
}

void main() {
  const desktop = AppTextThemeV3.desktop();
  const standard = AppTextThemeV3.standard();

  test('desktop body text is 13pt', () {
    expect(desktop.body.fontSize, 13);
  });

  test('no desktop style is smaller than 10pt', () {
    for (final entry in _stylesOf(desktop).entries) {
      expect(entry.value.fontSize, greaterThanOrEqualTo(10), reason: entry.key);
    }
  });

  test('every desktop style keeps the family, weight and number features of its standard counterpart', () {
    final standardStyles = _stylesOf(standard);
    for (final entry in _stylesOf(desktop).entries) {
      final reference = standardStyles[entry.key]!;
      expect(entry.value.fontFamily, reference.fontFamily, reason: entry.key);
      expect(entry.value.fontWeight, reference.fontWeight, reason: entry.key);
      expect(entry.value.fontFeatures, reference.fontFeatures, reason: entry.key);
    }
  });

  testWidgets('darkTheme installs the text theme it is given', (tester) async {
    final context = await _pumpContext(tester);

    final theme = AppTheme.darkTheme(context, text: desktop);

    expect(theme.extension<AppTextThemeV3>(), same(desktop));
    expect(theme.inputDecorationTheme.hintStyle?.fontSize, 13);
  });

  testWidgets('darkTheme installs the standard text theme when given none', (tester) async {
    final context = await _pumpContext(tester);

    final theme = AppTheme.darkTheme(context);

    expect(theme.extension<AppTextThemeV3>(), same(standard));
    expect(theme.inputDecorationTheme.hintStyle?.fontSize, 14);
  });
}
