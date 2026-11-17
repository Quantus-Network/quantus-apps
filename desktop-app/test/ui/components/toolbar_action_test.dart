import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _colors = AppColorsV3.dark();

/// The two kinds of action: one with an app icon, one with a system symbol.
enum _Kind { icon, symbol }

Future<void> _pump(WidgetTester tester, {required VoidCallback? onPressed, _Kind kind = _Kind.icon}) async {
  await tester.pumpWidget(
    Builder(
      builder: (context) => MaterialApp(
        theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
        home: Scaffold(
          body: Center(
            child: switch (kind) {
              _Kind.icon => ToolbarAction(icon: QuantusIcons.actionSend, label: 'Send', onPressed: onPressed),
              _Kind.symbol => ToolbarAction.symbol(
                symbol: CupertinoIcons.doc_on_clipboard,
                label: 'Send',
                onPressed: onPressed,
              ),
            },
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

  _testOnDesktop('a symbol action draws its symbol in the accent colour, at the icon size', (tester) async {
    await _pump(tester, onPressed: () {}, kind: _Kind.symbol);

    expect(find.text('Send'), findsOneWidget);
    expect(find.byType(QuantusIcon), findsNothing);
    final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.doc_on_clipboard));
    expect(icon.color, _colors.accentFlare);
    expect(icon.size, 16);
    expect(_backing(tester), 0);
  });

  for (final kind in _Kind.values) {
    _behaviour(kind);
  }
}

/// How an action of [kind] answers the mouse and the keyboard.
void _behaviour(_Kind kind) {
  _testOnDesktop(
    '${kind.name}: a backing appears under the cursor, grows stronger while pressed, and goes when the cursor leaves',
    (tester) async {
      var presses = 0;
      await _pump(tester, onPressed: () => presses++, kind: kind);
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
    },
  );

  _testOnDesktop('${kind.name}: the cursor stays an arrow over it, as over any macOS button', (tester) async {
    await _pump(tester, onPressed: () {}, kind: kind);
    final mouse = await _mouse(tester);

    await mouse.moveTo(tester.getCenter(find.byType(ToolbarAction)));
    await tester.pump();

    expect(tester.binding.mouseTracker.debugDeviceActiveCursor(1), SystemMouseCursors.basic);
  });

  _testOnDesktop('${kind.name}: an unavailable action is dimmed, shows no backing and does nothing when clicked', (
    tester,
  ) async {
    await _pump(tester, onPressed: null, kind: kind);
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

  _testOnDesktop('${kind.name}: Tab reaches it and shows a focus ring, and Space presses it', (tester) async {
    var presses = 0;
    await _pump(tester, onPressed: () => presses++, kind: kind);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_hasFocusRing(tester), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(presses, 1);
  });

  _testOnDesktop('${kind.name}: Tab passes over an unavailable action', (tester) async {
    await _pump(tester, onPressed: null, kind: kind);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_hasFocusRing(tester), isFalse);
  });

  _testOnDesktop('${kind.name}: a screen reader can press an available action', (tester) async {
    final semantics = tester.ensureSemantics();
    var presses = 0;
    await _pump(tester, onPressed: () => presses++, kind: kind);

    final node = tester.getSemantics(find.byType(ToolbarAction));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
    );
    await tester.pump();

    expect(presses, 1);
    semantics.dispose();
  });

  _testOnDesktop('${kind.name}: a screen reader is offered no press on an unavailable action', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, onPressed: null, kind: kind);

    expect(tester.getSemantics(find.byType(ToolbarAction)).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  group('ToolbarActionRow', () {
    /// A row of two actions held against [edge] of a 400pt box, inside a
    /// 40pt margin, as a sheet's content sits inside its padding.
    Future<List<int>> pumpRow(WidgetTester tester, ToolbarActionEdge edge) async {
      final pressed = <int>[];
      await tester.pumpWidget(
        Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
            home: Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: SizedBox(
                    key: const Key('content'),
                    width: 400,
                    child: Align(
                      alignment: edge == ToolbarActionEdge.trailing ? Alignment.centerRight : Alignment.centerLeft,
                      child: ToolbarActionRow(
                        edge: edge,
                        children: [
                          ToolbarAction.symbol(
                            symbol: CupertinoIcons.eye,
                            label: 'First',
                            onPressed: () => pressed.add(0),
                          ),
                          ToolbarAction.symbol(
                            symbol: CupertinoIcons.doc_on_doc,
                            label: 'Last',
                            onPressed: () => pressed.add(1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return pressed;
    }

    Rect backingOf(WidgetTester tester, String label) => tester.getRect(
      find.descendant(of: find.widgetWithText(ToolbarAction, label), matching: find.byKey(ToolbarAction.backingKey)),
    );

    _testOnDesktop('trailing, the last label ends on the edge; its backing reaches past it, its click stops there', (
      tester,
    ) async {
      final pressed = await pumpRow(tester, ToolbarActionEdge.trailing);
      final content = tester.getRect(find.byKey(const Key('content')));

      expect(tester.getRect(find.text('Last')).right, moreOrLessEquals(content.right, epsilon: 0.5));
      expect(backingOf(tester, 'Last').right, moreOrLessEquals(content.right + ToolbarAction.inset, epsilon: 0.5));

      final y = tester.getCenter(find.text('Last')).dy;
      await tester.tapAt(Offset(content.right + 2, y), kind: PointerDeviceKind.mouse);
      expect(pressed, isEmpty, reason: 'past the edge, where only the backing is');
      await tester.tapAt(Offset(content.right - 1, y), kind: PointerDeviceKind.mouse);
      expect(pressed, [1]);
    });

    _testOnDesktop('leading, the first icon starts on the edge; its backing reaches past it, its click stops there', (
      tester,
    ) async {
      final pressed = await pumpRow(tester, ToolbarActionEdge.leading);
      final content = tester.getRect(find.byKey(const Key('content')));

      expect(tester.getRect(find.byIcon(CupertinoIcons.eye)).left, moreOrLessEquals(content.left, epsilon: 0.5));
      expect(backingOf(tester, 'First').left, moreOrLessEquals(content.left - ToolbarAction.inset, epsilon: 0.5));

      final y = tester.getCenter(find.text('First')).dy;
      await tester.tapAt(Offset(content.left - 2, y), kind: PointerDeviceKind.mouse);
      expect(pressed, isEmpty, reason: 'past the edge, where only the backing is');
      await tester.tapAt(Offset(content.left + 1, y), kind: PointerDeviceKind.mouse);
      expect(pressed, [0]);
    });
  });
}
