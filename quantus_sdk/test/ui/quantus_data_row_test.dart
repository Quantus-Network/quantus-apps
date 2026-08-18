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

  BoxDecoration decorationAround(WidgetTester tester, String text) {
    final container = tester.widget<Container>(
      find.ancestor(of: find.text(text), matching: find.byType(Container)).first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('renders uppercase label and value', (tester) async {
    await pumpRow(tester, const QuantusDataRow(label: 'Hash', value: '0xa5f3c2...e3a6c8f1'));

    expect(find.text('HASH'), findsOneWidget);
    expect(find.text('Hash'), findsNothing);
    expect(find.text('0xa5f3c2...e3a6c8f1'), findsOneWidget);
  });

  testWidgets('paints hairline border and v3 md radius', (tester) async {
    await pumpRow(tester, const QuantusDataRow(label: 'Hash', value: '0xabc'));

    final decoration = decorationAround(tester, 'HASH');
    final border = decoration.border! as Border;
    expect(border.top.color, colors.borderHairline);
    expect(border.top.width, 1);
    expect(decoration.borderRadius, const AppRadiusV3.standard().mdBorder);
  });

  testWidgets('uses muted label and content value tokens', (tester) async {
    await pumpRow(tester, const QuantusDataRow(label: 'Hash', value: '0xabc'));

    final label = tester.widget<Text>(find.text('HASH'));
    expect(label.style?.color, colors.textMuted);
    expect(label.style?.fontSize, 10);
    expect(label.style?.letterSpacing, 1);
    expect(label.style?.fontFamily, AppTextTheme.fontFamilySecondary);

    final value = tester.widget<Text>(find.text('0xabc'));
    expect(value.style?.color, colors.textContent);
    expect(value.style?.fontSize, text.dataAddress.fontSize);
    expect(value.style?.fontFamily, AppTextTheme.fontFamilySecondary);
    expect(value.textAlign, TextAlign.right);
  });

  testWidgets('tapping invokes onTap', (tester) async {
    var tapped = false;
    await pumpRow(tester, QuantusDataRow(label: 'Hash', value: '0xabc', onTap: () => tapped = true));

    await tester.tap(find.text('HASH'));
    expect(tapped, isTrue);
  });

  testWidgets('shows trailing glyph when provided', (tester) async {
    await pumpRow(tester, const QuantusDataRow(label: 'Hash', value: '0xabc', trailing: Icon(Icons.chevron_right)));

    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
