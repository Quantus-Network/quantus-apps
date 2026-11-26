import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsAction, SemanticsActionEvent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
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
  double maxWidth = double.infinity,
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
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

  group('a label longer than its room', () {
    final long = 'Treasury' * 11;
    final items = [PopUpItem('long', long), const PopUpItem('en', 'English')];

    testWidgets('is cut short on one line in the button, the chevrons kept inside it', (tester) async {
      await _pump(tester, chosen: [], items: items, value: 'long', maxWidth: 200);

      expect(tester.takeException(), isNull);
      final button = tester.getRect(find.byType(PopUpButton<String>));
      expect(button.width, lessThanOrEqualTo(200));
      expect(button.height, 26);
      final chevrons = tester.getRect(
        find.descendant(of: find.byType(PopUpButton<String>), matching: find.byType(Icon)),
      );
      expect(chevrons.right, lessThanOrEqualTo(button.right));
      expect(chevrons.center.dy, closeTo(button.center.dy, 0.5));
      final label = tester.widget<Text>(_inButton(long));
      expect((label.maxLines, label.overflow), (1, TextOverflow.ellipsis));
    });

    testWidgets('is cut short on one line in the open menu, inside a narrow window', (tester) async {
      await _pump(tester, chosen: [], items: items, value: 'en', size: const Size(300, 400), maxWidth: 200);

      await _open(tester);

      expect(tester.takeException(), isNull);
      final menu = tester.getRect(_menu);
      expect(menu.left, greaterThanOrEqualTo(0));
      expect(menu.right, lessThanOrEqualTo(300));
      expect(
        tester.getRect(find.ancestor(of: _inMenu(long), matching: find.byType(MenuPanelRow))).height,
        PopUpButton.rowHeight,
      );
      // One line, as high as a short label's.
      expect(tester.getSize(_inMenu(long)).height, tester.getSize(_inMenu('English')).height);
    });
  });

  testWidgets('in a row that sets no width, the button takes its label\'s whole width', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Theme(
            data: AppTheme.darkTheme(context, text: const AppTextThemeV3.desktop()),
            child: Scaffold(
              body: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PopUpButton<String>(semanticLabel: 'Language', items: _items, value: 'id', onSelected: (_) {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.getRect(_inButton('Bahasa Indonesia'));
    final chevrons = tester.getRect(find.descendant(of: find.byType(PopUpButton<String>), matching: find.byType(Icon)));
    expect(chevrons.left, greaterThanOrEqualTo(label.right));
  });

  group('more items than the window holds', () {
    final many = [for (var i = 0; i < 30; i++) PopUpItem('s$i', 'Signer $i')];
    const window = Size(400, 300);

    /// Whether [label]'s row lies wholly inside the open menu, where a click
    /// reaches it.
    bool inView(WidgetTester tester, String label) {
      final menu = tester.getRect(_menu);
      final row = tester.getRect(_inMenu(label));
      return row.top >= menu.top && row.bottom <= menu.bottom && _inMenu(label).hitTestable().evaluate().isNotEmpty;
    }

    testWidgets('the menu stays inside the window and scrolls to its last item, which can be chosen', (tester) async {
      final chosen = <String>[];
      await _pump(tester, chosen: chosen, items: many, value: 's0', size: window);

      await _open(tester);

      expect(tester.takeException(), isNull);
      final menu = tester.getRect(_menu);
      expect((menu.top >= 0, menu.bottom <= window.height), (true, true));
      expect(inView(tester, 'Signer 29'), isFalse);

      await tester.drag(_inMenu('Signer 10'), const Offset(0, -1000));
      await tester.pumpAndSettle();
      expect(inView(tester, 'Signer 29'), isTrue);

      await tester.tap(_inMenu('Signer 29'));
      await tester.pumpAndSettle();
      expect(chosen, ['s29']);
    });

    testWidgets('the current item is in view when the menu opens', (tester) async {
      await _pump(tester, chosen: [], items: many, value: 's25', size: window);

      await _open(tester);

      expect(inView(tester, 'Signer 25'), isTrue);
    });

    testWidgets('Down to the last item keeps it in view, and Return picks it', (tester) async {
      final chosen = <String>[];
      await _pump(tester, chosen: chosen, items: many, value: 's0', size: window);
      await _open(tester);

      for (var i = 0; i < 29; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      }
      await tester.pumpAndSettle();
      expect(inView(tester, 'Signer 29'), isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(chosen, ['s29']);
    });
  });
}
