import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/hover_popover.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _target = Key('target');

/// A 100 by 20 target at [alignment] in an 800 by 600 window, whose popover
/// says "Inside" and points 12 into it.
Future<void> _pump(
  WidgetTester tester, {
  Alignment alignment = const Alignment(-0.5, -0.5),
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: Scaffold(
            body: Align(
              alignment: alignment,
              child: const HoverPopover(
                anchorX: 12,
                popover: SizedBox(width: 160, height: 60, child: Text('Inside')),
                child: SizedBox(key: _target, width: 100, height: 20),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(1, 1));
  addTearDown(mouse.removePointer);
  return mouse;
}

Finder get _inside => find.text('Inside');

void main() {
  testWidgets('it opens after 0.5 s of hover, not before, under what it is about, its arrow pointing at it', (
    tester,
  ) async {
    await _pump(tester);
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(find.byKey(_target)));
    await tester.pump(const Duration(milliseconds: 450));
    expect(_inside, findsNothing);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(_inside, findsOne);

    final target = tester.getRect(find.byKey(_target));
    final arrow = tester.getRect(find.byKey(HoverPopover.arrowKey));
    final box = tester.getRect(find.byKey(HoverPopover.boxKey));
    expect(arrow.top, greaterThanOrEqualTo(target.bottom));
    expect(box.top, greaterThan(arrow.top), reason: 'the arrow stands on the box, pointing up at the target');
    expect(arrow.center.dx, moreOrLessEquals(target.left + 12, epsilon: 0.5));
  });

  testWidgets('a pointer that leaves within 0.5 s opens nothing', (tester) async {
    await _pump(tester);
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(find.byKey(_target)));
    await tester.pump(const Duration(milliseconds: 300));
    await mouse.moveTo(const Offset(790, 590));
    await tester.pump(const Duration(seconds: 1));

    expect(_inside, findsNothing);
  });

  testWidgets('the pointer can move into it; it closes 0.2 s after the pointer has left both, not before', (
    tester,
  ) async {
    await _pump(tester);
    final mouse = await _mouse(tester);
    await mouse.moveTo(tester.getCenter(find.byKey(_target)));
    await tester.pump(HoverPopover.openAfter);
    await tester.pumpAndSettle();

    await mouse.moveTo(tester.getCenter(find.byKey(HoverPopover.boxKey)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(_inside, findsOne, reason: 'held open while the pointer is in it');

    await mouse.moveTo(const Offset(790, 590));
    await tester.pump(const Duration(milliseconds: 150));
    expect(_inside, findsOne);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(_inside, findsNothing);
  });

  testWidgets('near the window\'s bottom it opens above, its arrow pointing down', (tester) async {
    await _pump(tester, alignment: const Alignment(-0.5, 0.98));
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(find.byKey(_target)));
    await tester.pump(HoverPopover.openAfter);
    await tester.pumpAndSettle();

    final target = tester.getRect(find.byKey(_target));
    final arrow = tester.getRect(find.byKey(HoverPopover.arrowKey));
    final box = tester.getRect(find.byKey(HoverPopover.boxKey));
    expect(arrow.bottom, lessThanOrEqualTo(target.top));
    expect(box.bottom, lessThan(arrow.bottom), reason: 'the arrow hangs from the box, pointing down at the target');
    expect(arrow.center.dx, moreOrLessEquals(target.left + 12, epsilon: 0.5));
  });

  group('appearing', () {
    double opacity(WidgetTester tester) =>
        tester.widget<FadeTransition>(find.byKey(HoverPopover.fadeKey)).opacity.value;

    testWidgets('it fades in', (tester) async {
      await _pump(tester);
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump(HoverPopover.openAfter);
      await tester.pump();

      expect(opacity(tester), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacity(tester), 1);
    });

    testWidgets('with Reduce Motion on, it appears at once', (tester) async {
      await _pump(tester, reduceMotion: true);
      final mouse = await _mouse(tester);
      await mouse.moveTo(tester.getCenter(find.byKey(_target)));
      await tester.pump(HoverPopover.openAfter);
      await tester.pump();

      expect(opacity(tester), 1);
    });
  });
}
