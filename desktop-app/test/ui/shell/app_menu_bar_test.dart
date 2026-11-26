import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/shell/app_menu_bar.dart';

const _ctrlS = SingleActivator(LogicalKeyboardKey.keyS, control: true);

List<PlatformMenu> _menusWith({required VoidCallback? onSend}) => [
  PlatformMenu(
    label: 'Account',
    menus: [PlatformMenuItem(label: 'Send', shortcut: _ctrlS, onSelected: onSend)],
  ),
];

Future<void> _pressCtrlS(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

void main() {
  group('the menu bar in the window', () {
    testWidgets('a key acts on the menus as they are when it is pressed, not as they were last drawn', (tester) async {
      var sends = 0;
      // Drawn while Send was unavailable; it has become available since.
      VoidCallback? onSend;
      await tester.pumpWidget(
        MaterialApp(
          home: AppMenuBar(
            useNativeMenuBar: false,
            menus: _menusWith(onSend: null),
            resolveMenus: () => _menusWith(onSend: onSend),
            child: const SizedBox(),
          ),
        ),
      );
      onSend = () => sends++;

      await _pressCtrlS(tester);

      expect(sends, 1);
    });

    testWidgets('the key of an item that is unavailable is left for whoever else listens', (tester) async {
      final unhandled = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) unhandled.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: AppMenuBar(
              useNativeMenuBar: false,
              menus: _menusWith(onSend: null),
              resolveMenus: () => _menusWith(onSend: null),
              child: const SizedBox(),
            ),
          ),
        ),
      );

      await _pressCtrlS(tester);

      expect(unhandled, contains(LogicalKeyboardKey.keyS));
    });

    testWidgets('the key of an available item is taken, and runs the item once', (tester) async {
      var sends = 0;
      final unhandled = <LogicalKeyboardKey>[];
      List<PlatformMenu> menus() => _menusWith(onSend: () => sends++);
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) unhandled.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: AppMenuBar(useNativeMenuBar: false, menus: menus(), resolveMenus: menus, child: const SizedBox()),
          ),
        ),
      );

      await _pressCtrlS(tester);

      expect(sends, 1);
      expect(unhandled, isNot(contains(LogicalKeyboardKey.keyS)));
    });
  });

  group('the native menu bar', () {
    testWidgets('a key acts on the menus as they are when it is pressed, not as the system last heard of them', (
      tester,
    ) async {
      var sends = 0;
      // Handed to the system while Send was unavailable; it has become
      // available since.
      VoidCallback? onSend;
      await tester.pumpWidget(
        MaterialApp(
          home: AppMenuBar(
            useNativeMenuBar: true,
            menus: _menusWith(onSend: null),
            resolveMenus: () => _menusWith(onSend: onSend),
            child: const SizedBox(),
          ),
        ),
      );
      onSend = () => sends++;

      await _pressCtrlS(tester);

      expect(sends, 1);
    });

    testWidgets('the key of an item that is unavailable is left unhandled, for the system\'s menu to have', (
      tester,
    ) async {
      final unhandled = <LogicalKeyboardKey>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) unhandled.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: AppMenuBar(
              useNativeMenuBar: true,
              menus: _menusWith(onSend: null),
              resolveMenus: () => _menusWith(onSend: null),
              child: const SizedBox(),
            ),
          ),
        ),
      );

      await _pressCtrlS(tester);

      expect(unhandled, contains(LogicalKeyboardKey.keyS));
    });

    testWidgets('the key of an available item is taken, so the system\'s menu does not run the item again', (
      tester,
    ) async {
      var sends = 0;
      final unhandled = <LogicalKeyboardKey>[];
      List<PlatformMenu> menus() => _menusWith(onSend: () => sends++);
      await tester.pumpWidget(
        MaterialApp(
          home: Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent) unhandled.add(event.logicalKey);
              return KeyEventResult.ignored;
            },
            child: AppMenuBar(useNativeMenuBar: true, menus: menus(), resolveMenus: menus, child: const SizedBox()),
          ),
        ),
      );

      await _pressCtrlS(tester);

      expect(sends, 1);
      expect(unhandled, isNot(contains(LogicalKeyboardKey.keyS)));
      expect(find.byType(PlatformMenuBar), findsOneWidget);
    });
  });

  group('a submenu', () {
    List<PlatformMenu> withSubmenu(VoidCallback onChosen) => [
      PlatformMenu(
        label: 'Account',
        menus: [
          PlatformMenuItemGroup(
            members: [
              PlatformMenu(
                label: 'New Account',
                menus: [
                  PlatformMenuItem(label: 'Wallet 1', onSelected: () {}),
                  PlatformMenuItem(label: 'Wallet 2', shortcut: _ctrlS, onSelected: onChosen),
                ],
              ),
            ],
          ),
        ],
      ),
    ];

    testWidgets('is drawn by the menu bar in the window, and its items can be chosen', (tester) async {
      var chosen = 0;
      final menus = withSubmenu(() => chosen++);
      await tester.pumpWidget(
        MaterialApp(
          home: AppMenuBar(useNativeMenuBar: false, menus: menus, resolveMenus: () => menus, child: const SizedBox()),
        ),
      );

      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallet 2'));
      await tester.pumpAndSettle();

      expect(chosen, 1);
    });

    for (final useNativeMenuBar in [false, true]) {
      testWidgets('answers the shortcut of an item in it (native menu bar: $useNativeMenuBar)', (tester) async {
        var chosen = 0;
        final menus = withSubmenu(() => chosen++);
        final platform = useNativeMenuBar ? TargetPlatform.macOS : TargetPlatform.windows;
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.pumpWidget(
          MaterialApp(
            home: AppMenuBar(
              useNativeMenuBar: useNativeMenuBar,
              menus: menus,
              resolveMenus: () => menus,
              child: const SizedBox(),
            ),
          ),
        );

        await _pressCtrlS(tester);
        debugDefaultTargetPlatformOverride = null;

        expect(chosen, 1);
      });
    }
  });
}
