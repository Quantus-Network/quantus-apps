import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _colors = AppColorsV3.dark();

Future<void> _pump(WidgetTester tester, TerminalLine line) => tester.pumpWidget(
  Builder(
    builder: (context) => MaterialApp(
      theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
      home: Scaffold(body: SizedBox(width: 600, child: line)),
    ),
  ),
);

Color _colorOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!.color!;

void main() {
  testWidgets('draws the name in capitals after a prompt, and its status at the line\'s end in sage', (tester) async {
    await _pump(tester, const TerminalLine(name: 'Generate proofs', status: '[OK]'));

    expect(find.text('> GENERATE PROOFS'), findsOneWidget);
    expect(_colorOf(tester, '[OK]'), _colors.semanticSage);
    expect(tester.getRect(find.text('[OK]')).right, 600);
    expect(tester.getRect(find.text('> GENERATE PROOFS')).left, 0);
  });

  testWidgets('a status can have its own colour', (tester) async {
    await _pump(
      tester,
      TerminalLine(name: 'Building privacy proof', status: '[FAILED]', statusColor: _colors.semanticEmber),
    );

    expect(_colorOf(tester, '[FAILED]'), _colors.semanticEmber);
  });

  testWidgets('with no status it is the name alone, with no leaders', (tester) async {
    await _pump(tester, const TerminalLine(name: 'Submitting to chain'));

    expect(find.text('> SUBMITTING TO CHAIN'), findsOneWidget);
    expect(find.textContaining('....'), findsNothing);
  });

  testWidgets('a dim line is fainter than one that is not', (tester) async {
    await _pump(tester, const TerminalLine(name: 'Submitting to chain', isDim: true));
    final dim = _colorOf(tester, '> SUBMITTING TO CHAIN');

    await _pump(tester, const TerminalLine(name: 'Submitting to chain'));

    expect(dim, _colors.textMuted2);
    expect(_colorOf(tester, '> SUBMITTING TO CHAIN'), _colors.textMuted);
  });

  testWidgets('a screen reader gets the name as it is written, with the status', (tester) async {
    await _pump(tester, const TerminalLine(name: 'Generate proofs', status: '[OK]'));

    expect(find.bySemanticsLabel('Generate proofs [OK]'), findsOneWidget);
  });
}
