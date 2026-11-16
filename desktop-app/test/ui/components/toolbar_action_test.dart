import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _colors = AppColorsV3.dark();

Future<void> _pump(WidgetTester tester, {required VoidCallback? onPressed}) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(
          body: Center(
            child: ToolbarAction(icon: QuantusIcons.actionSend, label: 'Send', onPressed: onPressed),
          ),
        ),
      ),
    ),
  );
}

/// How strong the backing behind the action is: 0 when there is none.
double _backing(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(ToolbarAction), matching: find.byKey(ToolbarAction.backingKey)),
  );
  return (box.decoration as BoxDecoration).color!.a;
}

bool _hasFocusRing(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(of: find.byType(ToolbarAction), matching: find.byKey(ToolbarAction.focusRingKey)),
  );
  return (box.decoration as BoxDecoration).border != null;
}

Future<TestGesture> _mouse(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  return mouse;
}

/// A widget test run once as each desktop platform: the action's hover and
/// focus states only exist where there is a mouse and a keyboard.
void _testOnDesktop(String description, WidgetTesterCallback body) {
  testWidgets(description, body, variant: TargetPlatformVariant.desktop());
}

void main() {
  _testOnDesktop('at rest it is its icon in the accent colour and its label, with nothing behind them', (tester) async {
    await _pump(tester, onPressed: () {});

    expect(find.text('Send'), findsOneWidget);
    final icon = tester.widget<QuantusIcon>(find.byType(QuantusIcon));
    expect(icon.icon, QuantusIcons.actionSend);
    expect(icon.color, _colors.accentFlare);
    expect(_backing(tester), 0);
    expect(_hasFocusRing(tester), isFalse);
  });

  _testOnDesktop('a backing appears under the cursor, grows stronger while pressed, and goes when the cursor leaves', (
    tester,
  ) async {
    var presses = 0;
    await _pump(tester, onPressed: () => presses++);
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(find.byType(ToolbarAction)));
    await tester.pump();
    final hovered = _backing(tester);

    expect(hovered, greaterThan(0));

    await mouse.down(tester.getCenter(find.byType(ToolbarAction)));
    await tester.pump();

    expect(_backing(tester), greaterThan(hovered));
    expect(presses, 0);

    await mouse.up();
    await tester.pump();

    expect(presses, 1);
    expect(_backing(tester), hovered);

    await mouse.moveTo(Offset.zero);
    await tester.pump();

    expect(_backing(tester), 0);
  });

  _testOnDesktop('the cursor stays an arrow over it, as over any macOS button', (tester) async {
    await _pump(tester, onPressed: () {});
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(find.byType(ToolbarAction)));
    await tester.pump();

    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
  });

  _testOnDesktop('an unavailable action is dimmed, shows no backing and does nothing when clicked', (tester) async {
    await _pump(tester, onPressed: null);
    final mouse = await _mouse(tester);

    expect(
      tester.widget<Opacity>(find.descendant(of: find.byType(ToolbarAction), matching: find.byType(Opacity))).opacity,
      0.4,
    );

    await mouse.moveTo(tester.getCenter(find.byType(ToolbarAction)));
    await tester.pump();

    expect(_backing(tester), 0);

    await tester.tap(find.byType(ToolbarAction));
    await tester.pump();

    expect(_backing(tester), 0);
    expect(
      tester.getSemantics(find.byType(ToolbarAction)),
      isSemantics(isButton: true, hasEnabledState: true, isEnabled: false, label: 'Send'),
    );
  });

  _testOnDesktop('Tab reaches it and shows a focus ring, and Space presses it', (tester) async {
    var presses = 0;
    await _pump(tester, onPressed: () => presses++);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_hasFocusRing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(presses, 1);
  });

  _testOnDesktop('Tab passes over an unavailable action', (tester) async {
    await _pump(tester, onPressed: null);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_hasFocusRing(tester), isFalse);
  });
}
