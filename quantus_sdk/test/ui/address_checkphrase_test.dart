import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('paints the checkphrase in lilac under the address', (tester) async {
    await pump(tester, const AddressCheckphrase(address: 'qzAddr', checkphrase: 'alpha bravo'));

    expect(
      tester.getTopLeft(find.text('alpha bravo')).dy,
      greaterThan(tester.getBottomLeft(find.text('qzAddr')).dy - 1),
    );
    expect(tester.widget<Text>(find.text('alpha bravo')).style?.color, colors.semanticLilac);
    expect(tester.widget<Text>(find.text('qzAddr')).style?.fontFamily, AppTextThemeV3.fontFamilySecondary);
  });

  testWidgets('shows the placeholder until the checkphrase resolves', (tester) async {
    await pump(tester, const AddressCheckphrase(address: 'qzAddr', checkphrase: '', placeholder: Text('loading')));

    expect(find.text('loading'), findsOneWidget);
  });

  testWidgets('badges sit on the address line', (tester) async {
    await pump(
      tester,
      const AddressCheckphrase(
        address: 'qzAddr',
        checkphrase: 'alpha bravo',
        badges: [QuantusBadge(label: 'YOU')],
      ),
    );

    expect(tester.getCenter(find.text('YOU')).dy, closeTo(tester.getCenter(find.text('qzAddr')).dy, 4));
  });
}
