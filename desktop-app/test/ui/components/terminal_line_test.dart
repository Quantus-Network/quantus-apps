import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _colors = AppColorsV3.dark();

Future<void> _pump(WidgetTester tester, TerminalLine line, {bool reduceMotion = false}) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reduceMotion);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  return tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(body: SizedBox(width: 600, child: line)),
      ),
    ),
  );
}

/// The spinner's face on screen, if one is.
String? _face(WidgetTester tester) =>
    TerminalLine.busyFaces.where((face) => find.text(face).evaluate().isNotEmpty).singleOrNull;

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

  group('a busy line', () {
    testWidgets('turns a spinner where its status will stand, one face a turn, and round again', (tester) async {
      await _pump(tester, TerminalLine(name: 'Preparing', isBusy: true, statusColor: _colors.accentFlare));

      final faces = <String?>[];
      // Looked at in the middle of each turn.
      await tester.pump(TerminalLine.busyTurn ~/ 2);
      for (var turn = 0; turn < 5; turn++) {
        faces.add(_face(tester));
        await tester.pump(TerminalLine.busyTurn);
      }

      expect(faces, ['[|]', '[/]', '[-]', r'[\]', '[|]']);
      expect(tester.getRect(find.text(_face(tester)!)).right, 600);
      expect(_colorOf(tester, _face(tester)!), _colors.accentFlare);
      expect(find.textContaining('....'), findsOneWidget, reason: 'leaders run up to the spinner');
    });

    testWidgets('with a status shows it before the spinner, and neither moves as the spinner turns', (tester) async {
      await _pump(tester, const TerminalLine(name: 'Generate proofs', status: '3/8', isBusy: true));
      await tester.pump(TerminalLine.busyTurn ~/ 2);

      final count = tester.getRect(find.text('3/8'));
      final first = tester.getRect(find.text(_face(tester)!));
      expect(count.right, lessThan(first.left));
      expect(first.right, 600);

      await tester.pump(TerminalLine.busyTurn);

      expect(tester.getRect(find.text('3/8')), count);
      expect(tester.getRect(find.text(_face(tester)!)), first);
    });

    testWidgets('stops turning when it is no longer busy', (tester) async {
      await _pump(tester, const TerminalLine(name: 'Preparing', isBusy: true));
      await tester.pump(TerminalLine.busyTurn);
      expect(_face(tester), isNotNull);

      await _pump(tester, const TerminalLine(name: 'Preparing', status: '[OK]'));
      await tester.pumpAndSettle();

      expect(_face(tester), isNull);
      expect(find.text('[OK]'), findsOneWidget);
    });

    testWidgets('stands still where motion is unwanted: its status alone, or dots when it has none', (tester) async {
      await _pump(tester, const TerminalLine(name: 'Generate proofs', status: '3/8', isBusy: true), reduceMotion: true);
      await tester.pumpAndSettle();

      expect(_face(tester), isNull);
      expect(tester.getRect(find.text('3/8')).right, 600);

      await _pump(tester, const TerminalLine(name: 'Preparing', isBusy: true), reduceMotion: true);
      await tester.pumpAndSettle();

      expect(_face(tester), isNull);
      expect(tester.getRect(find.text('...')).right, 600);
    });

    testWidgets('is read to a screen reader by its name and status, without the spinner', (tester) async {
      await _pump(tester, const TerminalLine(name: 'Generate proofs', status: '3/8', isBusy: true));

      expect(find.bySemanticsLabel('Generate proofs 3/8'), findsOneWidget);

      await _pump(tester, const TerminalLine(name: 'Preparing', isBusy: true));

      expect(find.bySemanticsLabel('Preparing'), findsOneWidget);
    });
  });

  testWidgets('a name too long for its room is cut short, its status still whole at the end', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 240,
                child: TerminalLine(name: 'Sending wrapped ether to the recipient far away', status: '[OK]'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'nothing overflows');
    final line = tester.getRect(find.byType(TerminalLine));
    final status = tester.getRect(find.text('[OK]'));
    final name = tester.getRect(find.textContaining('> SENDING'));
    expect(status.right, line.right);
    expect(name.right, lessThanOrEqualTo(status.left));

    // In room enough, the name is whole, as ever.
    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                child: TerminalLine(name: 'Preparing', status: '[OK]'),
              ),
            ),
          ),
        ),
      ),
    );
    final whole = tester.renderObject<RenderParagraph>(find.text('> PREPARING'));
    expect(whole.didExceedMaxLines, isFalse);
  });

  testWidgets('a screen reader gets the name as it is written, with the status', (tester) async {
    await _pump(tester, const TerminalLine(name: 'Generate proofs', status: '[OK]'));

    expect(find.bySemanticsLabel('Generate proofs [OK]'), findsOneWidget);
  });
}
