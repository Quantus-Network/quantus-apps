import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../../fakes.dart';

const _cmdI = KeyCombo(LogicalKeyboardKey.keyI, KeyModifiers(meta: true));

/// A region with three items in two groups, Disconnect alone and in red, placed by
/// [alignment]; what is chosen lands in [chosen], and the region's own taps in [taps].
Future<void> _pump(
  WidgetTester tester, {
  required List<String> chosen,
  List<String>? taps,
  Alignment alignment = Alignment.center,
}) async {
  tester.view.physicalSize = const Size(800, 600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Theme(
          data: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
          child: Scaffold(
            body: Align(
              alignment: alignment,
              child: ContextMenuRegion(
                items: () => [
                  ContextMenuItem('Get Info', keys: _cmdI, onSelected: () => chosen.add('info')),
                  ContextMenuItem('Rename…', onSelected: () => chosen.add('rename')),
                  null,
                  ContextMenuItem('Disconnect…', isDestructive: true, onSelected: () => chosen.add('disconnect')),
                ],
                child: GestureDetector(
                  onTap: () {
                    if (ContextMenuRegion.isControlClick) return;
                    taps?.add('tap');
                  },
                  child: const SizedBox(width: 200, height: 40, child: Text('Savings')),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _menu => find.byKey(ContextMenuRegion.menuKey);

Future<void> _rightClick(WidgetTester tester, Offset at) async {
  final gesture = await tester.startGesture(at, kind: PointerDeviceKind.mouse, buttons: kSecondaryButton);
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a right-click opens the menu at the pointer', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    final at = tester.getCenter(find.text('Savings'));

    await _rightClick(tester, at);

    expect(_menu, findsOneWidget);
    final topLeft = tester.getTopLeft(_menu);
    expect(topLeft.dx, moreOrLessEquals(at.dx, epsilon: 1));
    expect(topLeft.dy, moreOrLessEquals(at.dy, epsilon: 1));
  });

  testOnMac('a Control-click opens the menu, and is not taken as a click', (tester) async {
    final chosen = <String>[];
    final taps = <String>[];
    await _pump(tester, chosen: chosen, taps: taps);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Savings')),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await gesture.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(_menu, findsOneWidget);
    expect(taps, isEmpty);
  });

  testWidgets('while its menu is open the region is ringed, as the item a menu acts on is', (tester) async {
    await _pump(tester, chosen: []);
    expect(find.byKey(ContextMenuRegion.ringKey), findsNothing);

    await _rightClick(tester, tester.getCenter(find.text('Savings')));
    expect(find.byKey(ContextMenuRegion.ringKey), findsOneWidget);
    expect(tester.getRect(find.byKey(ContextMenuRegion.ringKey)), tester.getRect(find.byType(ContextMenuRegion)));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(ContextMenuRegion.ringKey), findsNothing);
  });

  testWidgets('the arrow keys walk the items, past the separator, and Return chooses one', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _rightClick(tester, tester.getCenter(find.text('Savings')));

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(chosen, ['disconnect']);
    expect(_menu, findsNothing);
  });

  testWidgets('a click on an item chooses it and closes the menu', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _rightClick(tester, tester.getCenter(find.text('Savings')));

    await tester.tap(find.descendant(of: _menu, matching: find.text('Rename…')));
    await tester.pumpAndSettle();

    expect(chosen, ['rename']);
    expect(_menu, findsNothing);
  });

  testWidgets('Escape and a click outside close the menu without choosing', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _rightClick(tester, tester.getCenter(find.text('Savings')));
    expect(_menu, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_menu, findsNothing);

    await _rightClick(tester, tester.getCenter(find.text('Savings')));
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(_menu, findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('a null item is a separator, and a destructive item is drawn in ember', (tester) async {
    await _pump(tester, chosen: []);
    await _rightClick(tester, tester.getCenter(find.text('Savings')));

    expect(find.descendant(of: _menu, matching: find.byType(MenuPanelSeparator)), findsOneWidget);
    final disconnect = tester.widget<Text>(find.descendant(of: _menu, matching: find.text('Disconnect…')));
    final context = tester.element(_menu);
    expect(disconnect.style?.color, context.colorsV3.semanticEmber);
  });

  testOnMac('an item shows its shortcut, the modifiers as their symbols', (tester) async {
    await _pump(tester, chosen: []);
    await _rightClick(tester, tester.getCenter(find.text('Savings')));

    final row = find.ancestor(of: find.text('Get Info'), matching: find.byType(MenuPanelRow));
    expect(find.descendant(of: row, matching: find.byIcon(CupertinoIcons.command)), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('I')), findsOneWidget);
  });

  testWidgets('near the window\'s corner the menu moves inside it', (tester) async {
    await _pump(tester, chosen: [], alignment: Alignment.bottomRight);
    await _rightClick(tester, tester.getBottomRight(find.text('Savings')) - const Offset(2, 2));

    final menu = tester.getRect(_menu);
    expect(menu.right, lessThanOrEqualTo(800));
    expect(menu.bottom, lessThanOrEqualTo(600));
  });
}
