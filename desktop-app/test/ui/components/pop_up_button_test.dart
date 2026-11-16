import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _items = [PopUpItem('en', 'English'), PopUpItem('id', 'Bahasa Indonesia'), PopUpItem('fr', 'Français')];

/// A pop-up button showing [value], placed by [alignment] in a window of
/// [size]; what it reports lands in [chosen].
Future<void> _pump(
  WidgetTester tester, {
  required List<String> chosen,
  String value = 'id',
  List<PopUpItem<String>> items = _items,
  Alignment alignment = Alignment.center,
  Size size = const Size(800, 600),
}) async {
  tester.view.physicalSize = size;
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
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: PopUpButton<String>(
                  semanticLabel: 'Language',
                  items: items,
                  value: value,
                  onSelected: chosen.add,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _menu => find.byKey(PopUpButton.menuKey);

Finder _inMenu(String label) => find.descendant(of: _menu, matching: find.text(label));

Finder _inButton(String label) => find.descendant(of: find.byType(PopUpButton<String>), matching: find.text(label));

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byType(PopUpButton<String>));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a click opens the menu with the current item over the button, its label on the button\'s', (
    tester,
  ) async {
    await _pump(tester, chosen: []);
    final buttonLabel = tester.getRect(_inButton('Bahasa Indonesia'));

    await _open(tester);

    final itemLabel = tester.getRect(_inMenu('Bahasa Indonesia'));
    expect(itemLabel.center.dy, moreOrLessEquals(buttonLabel.center.dy, epsilon: 0.5));
    expect(itemLabel.left, moreOrLessEquals(buttonLabel.left, epsilon: 0.5));
  });

  testWidgets('only the current item has a checkmark', (tester) async {
    await _pump(tester, chosen: []);
    await _open(tester);

    final checks = find.descendant(of: _menu, matching: find.byKey(PopUpButton.checkmarkKey));
    expect(checks, findsOneWidget);
    expect(tester.getCenter(checks).dy, moreOrLessEquals(tester.getCenter(_inMenu('Bahasa Indonesia')).dy));
  });

  testWidgets('rows are 22 points high, and the menu covers the button', (tester) async {
    await _pump(tester, chosen: []);
    final button = tester.getRect(find.byType(PopUpButton<String>));
    await _open(tester);

    final first = tester.getCenter(_inMenu('English')).dy;
    final second = tester.getCenter(_inMenu('Bahasa Indonesia')).dy;
    final third = tester.getCenter(_inMenu('Français')).dy;
    expect(second - first, PopUpButton.rowHeight);
    expect(third - second, PopUpButton.rowHeight);
    final menu = tester.getRect(_menu);
    expect(menu.left, lessThanOrEqualTo(button.left));
    expect(menu.right, greaterThanOrEqualTo(button.right));
  });

  testWidgets('choosing an item reports it and closes the menu', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);

    await tester.tap(_inMenu('Français'));
    await tester.pumpAndSettle();

    expect(chosen, ['fr']);
    expect(_menu, findsNothing);
  });

  testWidgets('Escape closes the menu without choosing', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(_menu, findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('a click outside closes the menu without choosing', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(_menu, findsNothing);
    expect(chosen, isEmpty);
  });

  testWidgets('Tab reaches the button, Space opens it, and Down then Return picks the next item', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(_menu, findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(chosen, ['fr']);
    expect(_menu, findsNothing);
  });

  testWidgets('Up at the top stays on the first item', (tester) async {
    final chosen = <String>[];
    await _pump(tester, chosen: chosen);
    await _open(tester);

    for (var i = 0; i < 3; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(chosen, ['en']);
  });

  testWidgets('opened near the window\'s bottom edge, the menu stays inside the window', (tester) async {
    const size = Size(400, 300);
    await _pump(
      tester,
      chosen: [],
      value: 'en',
      items: [for (var i = 0; i < 8; i++) PopUpItem('$i', 'Item $i'), ..._items],
      alignment: Alignment.bottomLeft,
      size: size,
    );
    await _open(tester);

    final menu = tester.getRect(_menu);
    expect(menu.top, greaterThanOrEqualTo(0));
    expect(menu.bottom, lessThanOrEqualTo(size.height));
    expect(menu.left, greaterThanOrEqualTo(0));
  });

  testWidgets('the menu\'s labels are plain text, with no underline', (tester) async {
    await _pump(tester, chosen: []);
    await _open(tester);

    for (final item in _items) {
      final label = tester.widget<RichText>(find.descendant(of: _inMenu(item.label), matching: find.byType(RichText)));
      expect(label.text.style?.decoration ?? TextDecoration.none, TextDecoration.none, reason: item.label);
    }
  });

  testWidgets('draws no Material ink or menu', (tester) async {
    await _pump(tester, chosen: []);
    expect(find.descendant(of: find.byType(PopUpButton<String>), matching: find.byType(InkWell)), findsNothing);

    await _open(tester);

    expect(find.byType(MenuAnchor), findsNothing);
    expect(find.byType(MenuItemButton), findsNothing);
    expect(find.descendant(of: _menu, matching: find.byType(InkWell)), findsNothing);
  });

  testWidgets('a screen reader hears its name and the current item, and can press it', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, chosen: []);

    final node = tester.getSemantics(find.byType(PopUpButton<String>));
    final data = node.getSemanticsData();
    expect(data.label, 'Language');
    expect(data.value, 'Bahasa Indonesia');
    expect(data.flagsCollection.isButton, isTrue);

    tester.binding.performSemanticsAction(
      SemanticsActionEvent(type: SemanticsAction.tap, viewId: tester.view.viewId, nodeId: node.id),
    );
    await tester.pumpAndSettle();

    expect(_menu, findsOneWidget);
    semantics.dispose();
  });
}
