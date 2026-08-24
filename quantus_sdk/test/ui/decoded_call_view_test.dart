import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();
  const radius = AppRadiusV3.standard();

  final transfer = DecodedCall(
    pallet: 'Balances',
    call: 'transfer_allow_death',
    fields: [
      const ValueField('Destination', 'qzBob', kind: ValueKind.address),
      AmountField('Amount', BigInt.from(1000)),
      const ValueField('Hash', '0xabc', kind: ValueKind.hash),
    ],
  );

  Future<void> pumpView(WidgetTester tester, Widget view, {Size size = const Size(375, 667)}) async {
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

  DecodedCallView compactView({Widget Function(ValueField field)? addressBuilder}) {
    return DecodedCallView(
      call: transfer,
      layout: DetailSummaryLayout.compact,
      titleOf: (call) => call.displayTitle,
      formatAmount: (field) => '${field.token} QNT',
      addressBuilder: addressBuilder,
    );
  }

  testWidgets('compact layout titles the call and uses formatAmount', (tester) async {
    await pumpView(tester, compactView());

    expect(find.text('Balances · transfer_allow_death'), findsOneWidget);
    expect(find.text('qzBob'), findsOneWidget);
    expect(find.text('1000 QNT'), findsOneWidget);
    expect(find.text('0xabc'), findsOneWidget);

    final title = tester.widget<Text>(find.text('Balances · transfer_allow_death'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.labelData.fontSize);
  });

  testWidgets('addressBuilder replaces the address value row', (tester) async {
    await pumpView(tester, compactView(addressBuilder: (field) => Text('checkphrase for ${field.value}')));

    expect(find.text('checkphrase for qzBob'), findsOneWidget);
    expect(find.text('qzBob'), findsNothing);
  });

  testWidgets('nested call sits in a bordered card', (tester) async {
    final outer = DecodedCall(
      pallet: 'Multisig',
      call: 'approve',
      fields: [NestedCallField('Call', transfer, note: 'Inner payload')],
    );

    await pumpView(
      tester,
      DecodedCallView(
        call: outer,
        layout: DetailSummaryLayout.compact,
        titleOf: (call) => call.displayTitle,
        formatAmount: (field) => '${field.token}',
      ),
    );

    expect(find.text('Multisig · approve'), findsOneWidget);
    expect(find.text('Balances · transfer_allow_death'), findsOneWidget);
    expect(find.text('Inner payload'), findsOneWidget);

    final card = tester.widget<Container>(
      find.ancestor(of: find.text('Balances · transfer_allow_death'), matching: find.byType(Container)).first,
    );
    final decoration = card.decoration! as BoxDecoration;
    expect(decoration.color, colors.bgSurface2);
    expect(decoration.borderRadius, radius.mdBorder);
  });

  testWidgets('stacked layout uses the signing title style and uppercase groups', (tester) async {
    const grouped = DecodedCall(
      pallet: 'Utility',
      call: 'batch_all',
      fields: [
        FieldGroup('Calls', [ValueField('Index', '0', kind: ValueKind.number)]),
      ],
    );

    await pumpView(
      tester,
      DecodedCallView(
        call: grouped,
        layout: DetailSummaryLayout.stacked,
        titleOf: (call) => call.actionTitle,
        formatAmount: (field) => '${field.token}',
      ),
    );

    expect(find.text('UTILITY BATCH ALL'), findsOneWidget);
    expect(find.text('CALLS'), findsOneWidget);

    final title = tester.widget<Text>(find.text('UTILITY BATCH ALL'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.headingRow.fontSize);
  });
}
