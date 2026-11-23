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
            home: Scaffold(body: Center(child: child)),
          ),
        ),
      ),
    );
  }

  tearDown(() => CheckphraseText.resolveOverride = null);

  testWidgets('draws the resolved phrase in the given style', (tester) async {
    CheckphraseText.resolveOverride = (_) async => 'Alpha-Bravo';
    await pump(
      tester,
      CheckphraseText(
        'qzAddr',
        style: TextStyle(color: colors.semanticSage),
        textAlign: TextAlign.center,
      ),
    );
    await tester.pump();

    final phrase = tester.widget<Text>(find.text('Alpha-Bravo'));
    expect(phrase.style?.color, colors.semanticSage);
    expect(phrase.textAlign, TextAlign.center);
    expect(find.byType(Loader), findsNothing);
  });

  testWidgets('defaults to lilac body text', (tester) async {
    CheckphraseText.resolveOverride = (_) async => 'Alpha-Bravo';
    await pump(tester, const CheckphraseText('qzAddr'));
    await tester.pump();

    final phrase = tester.widget<Text>(find.text('Alpha-Bravo'));
    expect(phrase.style?.color, colors.semanticLilac);
    expect(phrase.style?.fontSize, const AppTextThemeV3.standard().body.fontSize);
  });

  testWidgets('keeps its height from the first frame through the spinner to the phrase', (tester) async {
    final lookup = Completer<String?>();
    CheckphraseText.resolveOverride = (_) => lookup.future;
    await pump(tester, const CheckphraseText('qzAddr'));

    final reserved = tester.getSize(find.byType(CheckphraseText)).height;
    expect(reserved, greaterThan(0));
    expect(tester.widget<Text>(find.text(CheckphraseText.standIn)).style?.color, Colors.transparent);
    expect(find.byType(Loader), findsNothing);

    await tester.pump(CheckphraseText.spinnerDelay);
    expect(find.byType(Loader), findsOneWidget);
    expect(tester.getSize(find.byType(CheckphraseText)).height, reserved);

    lookup.complete('Alpha-Bravo');
    await tester.pump();
    await tester.pump();
    expect(find.byType(Loader), findsNothing);
    expect(find.text(CheckphraseText.standIn), findsNothing);
    expect(find.text('Alpha-Bravo'), findsOneWidget);
    expect(tester.getSize(find.byType(CheckphraseText)).height, reserved);
  });

  testWidgets('a late result for a previous address is ignored', (tester) async {
    final first = Completer<String?>();
    CheckphraseText.resolveOverride = (address) => address == 'qzFirst' ? first.future : Future.value('Phrase-Second');
    final address = ValueNotifier('qzFirst');
    addTearDown(address.dispose);
    await pump(
      tester,
      ValueListenableBuilder<String>(valueListenable: address, builder: (_, value, _) => CheckphraseText(value)),
    );

    address.value = 'qzSecond';
    await tester.pump();
    await tester.pump();
    expect(find.text('Phrase-Second'), findsOneWidget);

    first.complete('Phrase-First');
    await tester.pump();
    await tester.pump();
    expect(find.text('Phrase-Second'), findsOneWidget);
    expect(find.text('Phrase-First'), findsNothing);
  });

  testWidgets('says so when the lookup fails, at the same height', (tester) async {
    CheckphraseText.resolveOverride = (_) async => null;
    await pump(tester, const CheckphraseText('qzAddr'));
    final reserved = tester.getSize(find.byType(CheckphraseText)).height;
    await tester.pump();

    expect(find.text(CheckphraseText.unavailableText), findsOneWidget);
    expect(find.byType(Loader), findsNothing);
    expect(tester.getSize(find.byType(CheckphraseText)).height, reserved);
  });

  testWidgets('transform maps the stand-in and the phrase alike', (tester) async {
    final lookup = Completer<String?>();
    CheckphraseText.resolveOverride = (_) => lookup.future;
    await pump(tester, CheckphraseText('qzAddr', transform: (phrase) => phrase.split('-').first));

    expect(find.text('Harbor'), findsOneWidget);
    lookup.complete('Alpha-Bravo');
    await tester.pump();
    await tester.pump();
    expect(find.text('Alpha'), findsOneWidget);
  });

  testWidgets('onResolved hands out the phrase once it is known', (tester) async {
    CheckphraseText.resolveOverride = (_) async => 'Alpha-Bravo';
    final resolved = <String>[];
    await pump(tester, CheckphraseText('qzAddr', onResolved: resolved.add));
    await tester.pump();

    expect(resolved, ['Alpha-Bravo']);
  });
}
