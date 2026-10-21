import 'dart:async';

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

  setUp(() => CheckphraseText.resolveOverride = (_) async => 'alpha bravo');
  tearDown(() => CheckphraseText.resolveOverride = null);

  testWidgets('paints the checkphrase in lilac under the address', (tester) async {
    await pump(tester, const AddressCheckphrase(address: 'qzAddr'));

    expect(
      tester.getTopLeft(find.text('alpha bravo')).dy,
      greaterThan(tester.getBottomLeft(find.text('qzAddr')).dy - 1),
    );
    expect(tester.widget<Text>(find.text('alpha bravo')).style?.color, colors.semanticLilac);
    expect(tester.widget<Text>(find.text('qzAddr')).style?.fontFamily, AppTextThemeV3.fontFamilySecondary);
  });

  testWidgets('derives the phrase from the full address while drawing the display form', (tester) async {
    final lookedUp = <String>[];
    CheckphraseText.resolveOverride = (address) async {
      lookedUp.add(address);
      return 'alpha bravo';
    };
    await pump(tester, const AddressCheckphrase(address: 'qzFullAddress', displayAddress: 'qzFu…ess'));

    expect(find.text('qzFu…ess'), findsOneWidget);
    expect(find.text('qzFullAddress'), findsNothing);
    expect(lookedUp, ['qzFullAddress']);
  });

  testWidgets('reserves the checkphrase line before it resolves', (tester) async {
    final lookup = Completer<String?>();
    CheckphraseText.resolveOverride = (_) => lookup.future;
    await pump(tester, const AddressCheckphrase(address: 'qzAddr'));
    final reserved = tester.getSize(find.byType(AddressCheckphrase)).height;

    lookup.complete('alpha bravo');
    await tester.pump();
    await tester.pump();
    expect(find.text('alpha bravo'), findsOneWidget);
    expect(tester.getSize(find.byType(AddressCheckphrase)).height, reserved);
  });

  testWidgets('secondary replaces the checkphrase line', (tester) async {
    await pump(tester, const AddressCheckphrase(address: 'qzAddr', secondary: Text('Account 2')));

    expect(find.text('Account 2'), findsOneWidget);
    expect(find.byType(CheckphraseText), findsNothing);
  });

  testWidgets('badges sit on the address line', (tester) async {
    await pump(
      tester,
      const AddressCheckphrase(
        address: 'qzAddr',
        badges: [QuantusBadge(label: 'YOU')],
      ),
    );

    expect(tester.getCenter(find.text('YOU')).dy, closeTo(tester.getCenter(find.text('qzAddr')).dy, 4));
  });
}
