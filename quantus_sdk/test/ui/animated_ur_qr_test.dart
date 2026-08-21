import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parts = ['ur:bytes/1-3/first', 'ur:bytes/2-3/second', 'ur:bytes/3-3/third'];

  Future<void> pumpQr(WidgetTester tester, {required List<String> parts, int fps = 10, bool paused = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedUrQr(parts: parts, fps: fps, paused: paused),
        ),
      ),
    );
  }

  Finder qrPaintFinder() => find.descendant(of: find.byType(AnimatedUrQr), matching: find.byType(CustomPaint));

  QrPainter painterOf(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(qrPaintFinder());
    return paint.painter! as QrPainter;
  }

  testWidgets('paints a precomputed QR matrix instead of encoding in build', (tester) async {
    await pumpQr(tester, parts: parts);

    expect(qrPaintFinder(), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(painterOf(tester), isA<QrPainter>());
  });

  testWidgets('cycles to the next precomputed frame on each tick', (tester) async {
    await pumpQr(tester, parts: parts, fps: 10);

    final first = painterOf(tester);
    await tester.pump(const Duration(milliseconds: 100));
    final second = painterOf(tester);
    expect(identical(first, second), isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    final third = painterOf(tester);
    expect(identical(second, third), isFalse);

    await tester.pump(const Duration(milliseconds: 100));
    expect(identical(painterOf(tester), first), isTrue);
  });

  testWidgets('does not advance while paused', (tester) async {
    await pumpQr(tester, parts: parts, fps: 10, paused: true);

    final first = painterOf(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(identical(painterOf(tester), first), isTrue);
  });

  testWidgets('restarts the timer when fps changes', (tester) async {
    var fps = 1;
    late VoidCallback setFps;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              setFps = () => setState(() => fps = 10);
              return AnimatedUrQr(parts: parts, fps: fps);
            },
          ),
        ),
      ),
    );

    final first = painterOf(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(identical(painterOf(tester), first), isTrue, reason: '1 fps should not tick in 500ms');

    setFps();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(identical(painterOf(tester), first), isFalse);
  });

  testWidgets('starts animating when parts grow from one to many', (tester) async {
    var currentParts = const ['ur:bytes/only'];
    late VoidCallback growParts;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              growParts = () => setState(() => currentParts = parts);
              return AnimatedUrQr(parts: currentParts, fps: 10);
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    growParts();
    await tester.pump();
    final afterUpdate = painterOf(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(identical(painterOf(tester), afterUpdate), isFalse);
  });

  testWidgets('defaults fps to 15 and paused to false', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnimatedUrQr(parts: parts)),
      ),
    );

    final qr = tester.widget<AnimatedUrQr>(find.byType(AnimatedUrQr));
    expect(qr.fps, 15);
    expect(qr.paused, isFalse);
  });

  testWidgets('rejects an empty parts list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AnimatedUrQr(parts: [])),
      ),
    );
    expect(tester.takeException(), isAssertionError);
  });

  test('rejects a non-positive fps', () {
    expect(() => AnimatedUrQr(parts: parts, fps: 0), throwsA(isA<AssertionError>()));
  });
}
