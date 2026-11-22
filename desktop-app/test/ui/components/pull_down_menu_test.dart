import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A button placed by [alignment] that pulls down a menu: Plain, a separator,
/// and Wallets, whose submenu holds [walletCount] wallets. What is chosen
/// lands in [chosen].
Future<void> _pump(
  WidgetTester tester, {
  required List<String> chosen,
  Alignment alignment = Alignment.center,
  int walletCount = 3,
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
              child: Builder(
                builder: (button) => TextButton(
                  onPressed: () {
                    final box = button.findRenderObject()! as RenderBox;
                    showPullDownMenu(
                      button,
                      anchor: box.localToGlobal(Offset.zero) & box.size,
                      items: [
                        ContextMenuItem('Plain', onSelected: () => chosen.add('Plain')),
                        null,
                        ContextMenuItem.submenu(
                          'Wallets',
                          items: [
                            for (var i = 1; i <= walletCount; i++)
                              ContextMenuItem('Wallet $i', onSelected: () => chosen.add('Wallet $i')),
                          ],
                        ),
                      ],
                    );
                  },
                  child: const Text('Add'),
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

Finder get _submenu => find.byKey(ContextMenuRegion.submenuKey);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

Future<TestGesture> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
  return mouse;
}

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

bool _isLit(WidgetTester tester, String label) =>
    tester.widget<MenuPanelRow>(find.widgetWithText(MenuPanelRow, label)).isHighlighted;

void main() {
  testWidgets('it opens under its control when there is room', (tester) async {
    await _pump(tester, chosen: [], alignment: Alignment.topCenter);
    await _open(tester);

    expect(tester.getTopLeft(_menu).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextButton)).dy));
  });

  testWidgets('at the foot of the window it opens above its control', (tester) async {
    await _pump(tester, chosen: [], alignment: Alignment.bottomCenter);
    await _open(tester);

    expect(tester.getBottomLeft(_menu).dy, lessThanOrEqualTo(tester.getTopLeft(find.byType(TextButton)).dy));
  });

  testWidgets('an item with a submenu shows a chevron', (tester) async {
    await _pump(tester, chosen: []);
    await _open(tester);

    final wallets = find.ancestor(of: find.text('Wallets'), matching: find.byType(MenuPanelRow));
    expect(find.descendant(of: wallets, matching: find.byIcon(CupertinoIcons.chevron_right)), findsOneWidget);
    final plain = find.ancestor(of: find.text('Plain'), matching: find.byType(MenuPanelRow));
    expect(find.descendant(of: plain, matching: find.byIcon(CupertinoIcons.chevron_right)), findsNothing);
  });

  testWidgets('hovering an item opens its submenu beside it; moving to another item closes it', (tester) async {
    await _pump(tester, chosen: []);
    await _open(tester);
    expect(_submenu, findsNothing);

    final mouse = await _hover(tester, find.text('Wallets'));
    expect(_submenu, findsOneWidget);
    expect(tester.getTopLeft(_submenu).dx, greaterThan(tester.getCenter(_menu).dx));

    await mouse.moveTo(tester.getCenter(find.text('Plain')));
    await tester.pumpAndSettle();
    expect(_submenu, findsNothing);
  });

  testWidgets('the pointer can travel from the item into its submenu', (tester) async {
    await _pump(tester, chosen: []);
    await _open(tester);
    final mouse = await _hover(tester, find.text('Wallets'));

    await mouse.moveTo(tester.getCenter(find.text('Wallet 2')));
    await tester.pumpAndSettle();

    expect(_submenu, findsOneWidget);
    expect(_isLit(tester, 'Wallet 2'), isTrue);
    expect(_isLit(tester, 'Wallets'), isTrue, reason: 'the item it hangs from stays lit');
  });

  testWidgets('a click on an item with a submenu opens it and chooses nothing', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);

    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();

    expect(_submenu, findsOneWidget);
    expect(chosen, isEmpty);
  });

  testWidgets('choosing in the submenu runs it and closes both menus', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);
    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wallet 2'));
    await tester.pumpAndSettle();

    expect(chosen, ['Wallet 2']);
    expect(_menu, findsNothing);
    expect(_submenu, findsNothing);
  });

  testWidgets('the arrows walk into the submenu and out of it, and Return chooses', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(_isLit(tester, 'Wallets'), isTrue);
    expect(_submenu, findsNothing);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    expect(_isLit(tester, 'Wallet 1'), isTrue);

    await _press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_submenu, findsNothing);
    expect(_isLit(tester, 'Wallets'), isTrue);

    await _press(tester, LogicalKeyboardKey.arrowRight);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.enter);

    expect(chosen, ['Wallet 2']);
    expect(_menu, findsNothing);
  });

  testWidgets('Return on an item with a submenu opens it', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);

    await _press(tester, LogicalKeyboardKey.enter);

    expect(_submenu, findsOneWidget);
    expect(chosen, isEmpty);
  });

  testWidgets('Escape closes one level at a time', (tester) async {
    await _pump(tester, chosen: []);
    await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(_submenu, findsNothing);
    expect(_menu, findsOneWidget);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(_menu, findsNothing);
  });

  testWidgets('a long submenu stays inside the window and scrolls to the item the keys reach', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen, walletCount: 60);
    await _open(tester);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowDown);
    await _press(tester, LogicalKeyboardKey.arrowRight);

    final panel = tester.getRect(_submenu);
    expect(panel.top, greaterThanOrEqualTo(ContextMenuRegion.windowMargin));
    expect(panel.bottom, lessThanOrEqualTo(600 - ContextMenuRegion.windowMargin));
    expect(tester.takeException(), isNull);

    for (var i = 0; i < 59; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    }
    await tester.pumpAndSettle();

    final last = tester.getRect(find.text('Wallet 60'));
    expect(last.bottom, lessThanOrEqualTo(panel.bottom));
    await _press(tester, LogicalKeyboardKey.enter);
    expect(chosen, ['Wallet 60']);
  });

  testWidgets('at the window\'s right edge the submenu opens on the left', (tester) async {
    await _pump(tester, chosen: [], alignment: Alignment.centerRight);
    await _open(tester);

    await tester.tap(find.text('Wallets'));
    await tester.pumpAndSettle();

    expect(tester.getTopRight(_submenu).dx, lessThanOrEqualTo(tester.getTopLeft(_menu).dx + 4));
    expect(tester.getTopLeft(_submenu).dx, greaterThanOrEqualTo(ContextMenuRegion.windowMargin));
  });
}
