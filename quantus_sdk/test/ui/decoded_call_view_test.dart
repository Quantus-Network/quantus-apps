import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  const dest = ValueField('Destination', 'qzDest', kind: ValueKind.address);
  final amount = AmountField('Amount', BigInt.from(1000));
  final transfer = DecodedCall(pallet: 'Balances', call: 'transfer_allow_death', fields: [dest, amount]);

  Future<void> pumpCall(WidgetTester tester, Widget view, {Size size = const Size(375, 667)}) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: SingleChildScrollView(child: view)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  DecodedCallView view({
    required DecodedCall call,
    DecodedCallLayout layout = DecodedCallLayout.compact,
    String? Function(String address)? checkphraseOf,
    int depth = 0,
  }) {
    return DecodedCallView(
      call: call,
      layout: layout,
      amountText: (token) => '$token QNT',
      checkphraseOf: checkphraseOf,
      depth: depth,
    );
  }

  testWidgets('renders pallet title, fields, and formatted native amount', (tester) async {
    await pumpCall(tester, view(call: transfer));

    expect(find.text('Balances · transfer_allow_death'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('qzDest'), findsOneWidget);
    expect(find.text('1000 QNT'), findsOneWidget);
  });

  testWidgets('stacked layout uppercases labels and wraps checkphrase in lilac', (tester) async {
    await pumpCall(
      tester,
      view(call: transfer, layout: DecodedCallLayout.stacked, checkphraseOf: (address) => 'alpha bravo charlie'),
    );

    expect(find.text('DESTINATION'), findsOneWidget);
    expect(find.text('DESTINATION CHECKPHRASE'), findsOneWidget);
    final phrase = tester.widget<Text>(find.text('alpha bravo charlie'));
    expect(phrase.style?.color, colors.semanticLilac);
  });

  testWidgets('compact layout keeps title-case labels and right-aligns values', (tester) async {
    await pumpCall(tester, view(call: transfer));

    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('DESTINATION'), findsNothing);
    final value = tester.widget<Text>(find.text('qzDest'));
    expect(value.textAlign, TextAlign.right);
    expect(value.style?.fontFamily, AppTextTheme.fontFamilySecondary);
  });

  testWidgets('nested call uses surface2 fill, hairline, and v3 md radius', (tester) async {
    const nested = DecodedCall(pallet: 'Balances', call: 'transfer_allow_death', fields: [dest]);
    const outer = DecodedCall(pallet: 'Multisig', call: 'as_multi', fields: [NestedCallField('Call', nested)]);

    await pumpCall(tester, view(call: outer));

    expect(find.text('Multisig · as_multi'), findsOneWidget);
    expect(find.text('Balances · transfer_allow_death'), findsOneWidget);

    final nestedTitle = tester.widget<Text>(find.text('Balances · transfer_allow_death'));
    expect(nestedTitle.style?.color, colors.textMuted);
    expect(nestedTitle.style?.fontSize, text.headingRow.fontSize);

    final container = tester.widget<Container>(
      find.ancestor(of: find.text('Balances · transfer_allow_death'), matching: find.byType(Container)).first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface2);
    expect(decoration.borderRadius, const AppRadiusV3.standard().mdBorder);
    final border = decoration.border! as Border;
    expect(border.top.color, colors.borderHairline);
  });

  testWidgets('asset amounts show raw units and the decimals caveat', (tester) async {
    final call = DecodedCall(
      pallet: 'Assets',
      call: 'transfer',
      fields: [AmountField('Amount', BigInt.from(99), assetId: 7)],
    );

    await pumpCall(tester, view(call: call));

    expect(find.text('99 raw units of asset #7'), findsOneWidget);
    expect(find.text('Asset decimals are not part of this payload, so the raw amount is shown.'), findsOneWidget);
  });

  testWidgets('hash fields use the mono data style', (tester) async {
    const call = DecodedCall(
      pallet: 'Preimage',
      call: 'note_preimage',
      fields: [ValueField('Hash', '0xdead', kind: ValueKind.hash)],
    );

    await pumpCall(tester, view(call: call));

    final hash = tester.widget<Text>(find.text('0xdead'));
    expect(hash.style?.fontFamily, AppTextTheme.fontFamilySecondary);
    expect(hash.style?.color, colors.textContent);
  });
}
