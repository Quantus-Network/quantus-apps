import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/models/app_command.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/providers/shortcut_bindings_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/key_caps.dart';
import 'package:quantus_desktop_wallet/ui/components/shortcut_recorder.dart';
import 'package:quantus_desktop_wallet/ui/settings/keyboard_shortcuts_step.dart';
import 'package:quantus_desktop_wallet/ui/settings/settings_sheet.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';

import '../../fakes.dart';

Finder _inSheet(Finder matching) => find.descendant(of: find.byType(ShellSheetView), matching: matching);

Finder _row(AppCommand command) => find.byKey(KeyboardShortcutsStep.shortcutKey(command));

/// The key names [command]'s row shows, in order.
List<String> _capsOf(WidgetTester tester, AppCommand command) =>
    tester.widget<KeyCaps>(find.descendant(of: _row(command), matching: find.byType(KeyCaps))).labels;

PlatformMenuItem _nativeItem(WidgetTester tester, String menu, String label) {
  final menus = tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus.cast<PlatformMenu>();
  return [
    for (final entry in menus.singleWhere((m) => m.label == menu).menus)
      if (entry is PlatformMenuItemGroup) ...entry.members else entry,
  ].singleWhere((item) => item.label == label);
}

/// Opens Settings › Keyboard Shortcuts on a device with a wallet.
Future<FakeWalletDevice> _openShortcuts(WidgetTester tester, {String? saved, Object? stray}) async {
  final device = FakeWalletDevice()..store([mainAccount, savingsAccount]);
  if (saved != null) device.storage.strings[ShortcutBindingsNotifier.settingsKey] = saved;
  if (stray != null) device.storage.strays[ShortcutBindingsNotifier.settingsKey] = stray;
  await pumpShell(tester, overrides: device.overrides);
  ProviderScope.containerOf(
    tester.element(find.byType(DesktopShell)),
  ).read(shellSheetProvider.notifier).open(ShellSheet.settings);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(SettingsSheet.keyboardShortcutsRowKey));
  await tester.pumpAndSettle();
  return device;
}

/// Presses [key] with the modifiers held.
Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool meta = false,
  bool control = false,
  bool alt = false,
  bool shift = false,
}) async {
  final held = [
    if (meta) LogicalKeyboardKey.metaLeft,
    if (control) LogicalKeyboardKey.controlLeft,
    if (alt) LogicalKeyboardKey.altLeft,
    if (shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final modifier in held) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(key);
  for (final modifier in held.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pumpAndSettle();
}

Future<void> _record(WidgetTester tester, AppCommand command) async {
  await tester.tap(_row(command));
  await tester.pumpAndSettle();
}

void main() {
  test('a key Flutter has no name for is called by its letter on its keycap', () {
    expect(KeyCaps.keyName(const LogicalKeyboardKey(0x00f6)), 'Ö');
  });

  testOnMac('the Keyboard Shortcuts row opens the step, and Back returns to the list', (tester) async {
    await _openShortcuts(tester);

    expect(_inSheet(find.text('Keyboard Shortcuts')), findsOneWidget);
    expect(_inSheet(find.text('Settings')), findsOneWidget);
    expect(_row(AppCommand.receive), findsOneWidget);

    await tester.tap(find.byKey(ShellSheetHeader.backKey));
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsSheet.keyboardShortcutsRowKey), findsOneWidget);
  });

  testOnMac('on the Mac each command shows its keys as keycaps, the modifiers with their symbol and name', (
    tester,
  ) async {
    await _openShortcuts(tester);

    expect(_capsOf(tester, AppCommand.receive), ['command', 'R']);
    expect(_capsOf(tester, AppCommand.send), ['command', 'S']);
    expect(_capsOf(tester, AppCommand.propose), ['command', 'P']);
    expect(_inSheet(find.text('Propose')), findsOneWidget);
    expect(_capsOf(tester, AppCommand.addAccount), ['command', 'N']);
    expect(_capsOf(tester, AppCommand.toggleSidebar), ['command', 'B']);
    expect(_capsOf(tester, AppCommand.nextSidebarItem), ['option', 'command', '↓']);
    expect(_capsOf(tester, AppCommand.previousSidebarItem), ['option', 'command', '↑']);
    expect(_capsOf(tester, AppCommand.refresh), ['shift', 'command', 'R']);
    expect(
      find.descendant(of: _row(AppCommand.receive), matching: find.byIcon(CupertinoIcons.command)),
      findsOneWidget,
    );
    expect(find.byKey(KeyboardShortcutsStep.accountKeysKey), findsOneWidget);
    expect(_inSheet(find.text('Command')), findsOneWidget);
  });

  testOnMac('the keys end on the content\'s edge, as the account keys\' digits do', (tester) async {
    await _openShortcuts(tester);

    final digits = tester.getRect(_inSheet(find.text('+  1 … 9')));
    for (final command in AppCommand.values) {
      final keys = tester.getRect(find.descendant(of: _row(command), matching: find.byType(KeyCaps)));
      expect(keys.right, moreOrLessEquals(digits.right), reason: command.name);
    }
  });

  testOnWindowsAndLinux('on Windows and Linux the keys are named in words, with no Mac symbol anywhere', (
    tester,
  ) async {
    await _openShortcuts(tester);

    expect(_capsOf(tester, AppCommand.receive), ['Ctrl', 'R']);
    expect(_capsOf(tester, AppCommand.nextSidebarItem), ['Ctrl', 'Alt', '↓']);
    expect(_capsOf(tester, AppCommand.refresh), ['Ctrl', 'Shift', 'R']);
    expect(_inSheet(find.text('Ctrl')), findsWidgets);
    for (final icon in [CupertinoIcons.command, CupertinoIcons.option, CupertinoIcons.control, CupertinoIcons.shift]) {
      expect(_inSheet(find.byIcon(icon)), findsNothing);
    }
  });

  testOnMac('a shortcut takes the keys pressed, and the menu shows them', (tester) async {
    final device = await _openShortcuts(tester);

    await _record(tester, AppCommand.nextSidebarItem);
    expect(
      find.descendant(of: _row(AppCommand.nextSidebarItem), matching: find.text('Type shortcut…')),
      findsOneWidget,
    );
    await _press(tester, LogicalKeyboardKey.keyJ, meta: true);

    expect(_capsOf(tester, AppCommand.nextSidebarItem), ['command', 'J']);
    final shortcut = _nativeItem(tester, 'View', 'Next Sidebar Item').shortcut! as SingleActivator;
    expect((shortcut.trigger, shortcut.meta, shortcut.alt), (LogicalKeyboardKey.keyJ, true, false));
    expect(device.storage.strings[ShortcutBindingsNotifier.settingsKey], isNotNull);
  });

  testOnMac('Refresh is listed under View, after the sidebar\'s items, and takes new keys as the others do', (
    tester,
  ) async {
    await _openShortcuts(tester);

    expect(_inSheet(find.text('Refresh')), findsOneWidget);
    final previous = tester.getRect(_row(AppCommand.previousSidebarItem));
    final refresh = tester.getRect(_row(AppCommand.refresh));
    expect(refresh.top, greaterThanOrEqualTo(previous.bottom));

    await tester.ensureVisible(_row(AppCommand.refresh));
    await _record(tester, AppCommand.refresh);
    await _press(tester, LogicalKeyboardKey.keyR, meta: true, alt: true);

    expect(_capsOf(tester, AppCommand.refresh), ['option', 'command', 'R']);
    final shortcut = _nativeItem(tester, 'View', 'Refresh').shortcut! as SingleActivator;
    expect(
      (shortcut.trigger, shortcut.meta, shortcut.alt, shortcut.shift),
      (LogicalKeyboardKey.keyR, true, true, false),
    );
  });

  testOnMac('Swap is listed under Account after Propose, with shift command S, and takes new keys as the others do', (
    tester,
  ) async {
    await _openShortcuts(tester);

    expect(_capsOf(tester, AppCommand.swap), ['shift', 'command', 'S']);
    expect(_inSheet(find.text('Swap')), findsOneWidget);
    final propose = tester.getRect(_row(AppCommand.propose));
    final swap = tester.getRect(_row(AppCommand.swap));
    final newAccount = tester.getRect(_row(AppCommand.addAccount));
    expect(swap.top, greaterThanOrEqualTo(propose.bottom));
    expect(newAccount.top, greaterThanOrEqualTo(swap.bottom));

    await _record(tester, AppCommand.swap);
    await _press(tester, LogicalKeyboardKey.keyS, meta: true, alt: true);

    expect(_capsOf(tester, AppCommand.swap), ['option', 'command', 'S']);
    final shortcut = _nativeItem(tester, 'Account', 'Swap').shortcut! as SingleActivator;
    expect(
      (shortcut.trigger, shortcut.meta, shortcut.alt, shortcut.shift),
      (LogicalKeyboardKey.keyS, true, true, false),
    );
  });

  testOnMac('Swap\'s keys, given to another command, are refused, naming Swap', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.nextSidebarItem);
    await _press(tester, LogicalKeyboardKey.keyS, meta: true, shift: true);

    expect(_inSheet(find.text('That shortcut is already used by Swap. Press other keys.')), findsOneWidget);
    expect(_capsOf(tester, AppCommand.swap), ['shift', 'command', 'S']);
  });

  testOnMac('while a shortcut waits for keys the menus have none, so the keys reach it', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);

    expect(_nativeItem(tester, 'View', 'Next Sidebar Item').shortcut, isNull);
    expect(_nativeItem(tester, 'Quantus Wallet', 'Settings…').shortcut, isNull);

    await _press(tester, LogicalKeyboardKey.escape);

    expect(_nativeItem(tester, 'View', 'Next Sidebar Item').shortcut, isNotNull);
  });

  testOnMac('Esc while waiting for keys leaves the shortcut as it was, and the sheet open', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.escape);

    expect(_capsOf(tester, AppCommand.send), ['command', 'S']);
    expect(find.byType(KeyboardShortcutsStep), findsOneWidget);
  });

  /// Whether [command]'s shortcut waits for new keys.
  bool recording(WidgetTester tester, AppCommand command) => tester.widget<ShortcutRecorder>(_row(command)).isRecording;

  for (final (test, key) in [(testOnMac, 'command'), (testOnWindowsAndLinux, 'Ctrl')]) {
    test('a click on another shortcut, while one waits for keys, makes that one wait instead', (tester) async {
      await _openShortcuts(tester);
      await _record(tester, AppCommand.receive);

      await _record(tester, AppCommand.send);

      expect(recording(tester, AppCommand.send), isTrue);
      expect(recording(tester, AppCommand.receive), isFalse);

      // The keys go to the one clicked last, and the first keeps its own.
      await _press(tester, LogicalKeyboardKey.keyJ, meta: key == 'command', control: key == 'Ctrl');

      expect(_capsOf(tester, AppCommand.send), [key, 'J']);
      expect(_capsOf(tester, AppCommand.receive), [key, 'R']);
      expect(recording(tester, AppCommand.send), isFalse);
    });
  }

  testOnMac('a shortcut that waits for keys stops waiting when the keyboard\'s focus leaves it', (tester) async {
    await _openShortcuts(tester);
    await _record(tester, AppCommand.send);
    expect(recording(tester, AppCommand.send), isTrue);

    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    expect(recording(tester, AppCommand.send), isFalse);
    expect(_capsOf(tester, AppCommand.send), ['command', 'S']);
  });

  testOnMac('Delete while waiting for keys removes the shortcut', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.backspace);

    expect(find.descendant(of: _row(AppCommand.send), matching: find.text('None')), findsOneWidget);
    expect(_nativeItem(tester, 'Account', 'Send').shortcut, isNull);
  });

  testOnMac('keys another command has are refused, naming it, and the shortcut stays as it was', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.nextSidebarItem);
    await _press(tester, LogicalKeyboardKey.keyR, meta: true);

    expect(_inSheet(find.text('That shortcut is already used by Receive. Press other keys.')), findsOneWidget);
    // It still waits, so other keys can be pressed.
    await _press(tester, LogicalKeyboardKey.keyJ, meta: true);
    expect(_capsOf(tester, AppCommand.nextSidebarItem), ['command', 'J']);
    expect(_inSheet(find.textContaining('already used')), findsNothing);
  });

  testOnMac('keys an account has are refused', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.digit2, meta: true);

    expect(
      _inSheet(find.text('That shortcut is already used by Go to account 1 to 9. Press other keys.')),
      findsOneWidget,
    );
  });

  testOnMac('keys the system keeps are refused, naming what for', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.keyC, meta: true);

    expect(_inSheet(find.text('That shortcut is kept for Copy. Press other keys.')), findsOneWidget);
    // The refused keys show until the recording ends; the shortcut kept its own.
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_capsOf(tester, AppCommand.send), ['command', 'S']);
  });

  testOnMac('a key with no modifier is refused', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.keyJ, shift: true);

    expect(_inSheet(find.text('Hold Command, Option or Control with the key.')), findsOneWidget);
  });

  testOnMac('a key the menu bar cannot give a menu item is refused, and the shortcut stays as it was', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.receive);
    await _press(tester, LogicalKeyboardKey.numpadAdd, meta: true);

    expect(_inSheet(find.text('The menu bar cannot use that key. Press other keys.')), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_capsOf(tester, AppCommand.receive), ['command', 'R']);
  });

  testOnWindowsAndLinux('a key of the number pad is taken', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.receive);
    await _press(tester, LogicalKeyboardKey.numpadAdd, control: true);

    expect(_inSheet(find.text('The menu bar cannot use that key. Press other keys.')), findsNothing);
    expect(_capsOf(tester, AppCommand.receive), isNot(['Ctrl', 'R']));
  });

  testOnWindowsAndLinux('keys held with the Windows key are refused', (tester) async {
    await _openShortcuts(tester);

    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.keyJ, meta: true, control: true);

    expect(_inSheet(find.text('Shortcuts with the Windows or Super key belong to the system.')), findsOneWidget);
    // The refused keys show until the recording ends; the shortcut kept its own.
    await _press(tester, LogicalKeyboardKey.escape);
    expect(_capsOf(tester, AppCommand.send), ['Ctrl', 'S']);
  });

  testOnMac('other account keys change the account items\' shortcuts', (tester) async {
    await _openShortcuts(tester);

    await tester.tap(find.byKey(KeyboardShortcutsStep.accountKeysKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option + Command').last);
    await tester.pumpAndSettle();

    final shortcut = _nativeItem(tester, 'Account', 'Savings').shortcut! as SingleActivator;
    expect((shortcut.trigger, shortcut.meta, shortcut.alt), (LogicalKeyboardKey.digit2, true, true));
  });

  testOnMac('account keys that would clash with a command are refused, naming it', (tester) async {
    await _openShortcuts(tester);
    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.digit5, control: true);

    await tester.tap(find.byKey(KeyboardShortcutsStep.accountKeysKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Control').last);
    await tester.pumpAndSettle();

    expect(_inSheet(find.text('Those keys would clash with Send.')), findsOneWidget);
    expect(_inSheet(find.text('Command')), findsOneWidget);
  });

  testOnMac('Restore Defaults puts every shortcut back', (tester) async {
    await _openShortcuts(tester);
    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.backspace);

    // Under the list, which scrolls.
    await tester.ensureVisible(find.byKey(KeyboardShortcutsStep.restoreKey));
    await tester.pump();
    await tester.tap(find.byKey(KeyboardShortcutsStep.restoreKey));
    await tester.pumpAndSettle();

    expect(_capsOf(tester, AppCommand.send), ['command', 'S']);
  });

  testOnMac('saved shortcuts that could not be read are reported, and the defaults are shown', (tester) async {
    await _openShortcuts(tester, saved: 'not json');

    expect(_inSheet(find.text('Your saved shortcuts could not be read, so the defaults are in use.')), findsOneWidget);
    expect(_capsOf(tester, AppCommand.send), ['command', 'S']);
  });

  for (final test in [testOnMac, testOnWindowsAndLinux]) {
    test('with a number saved where the shortcuts should be, the app opens, says they were lost, and Restore '
        'Defaults clears it', (tester) async {
      final device = await _openShortcuts(tester, stray: 7);

      expect(tester.takeException(), isNull);
      expect(find.byType(DesktopShell), findsOneWidget);
      final notice = _inSheet(find.textContaining('could not be read'));
      expect(notice, findsOneWidget);

      await tester.ensureVisible(find.byKey(KeyboardShortcutsStep.restoreKey));
      await tester.tap(find.byKey(KeyboardShortcutsStep.restoreKey));
      await tester.pumpAndSettle();

      expect(notice, findsNothing);
      expect(device.storage.strays, isEmpty);
      expect(device.storage.strings[ShortcutBindingsNotifier.settingsKey], isNotNull);
    });
  }

  testOnWindowsAndLinux('in the smallest window nothing overflows, and Restore Defaults can be scrolled to', (
    tester,
  ) async {
    await _openShortcuts(tester);
    // The smallest window the app allows.
    tester.view.physicalSize = const Size(960, 640);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(KeyboardShortcutsStep.restoreKey),
      50,
      scrollable: find.descendant(of: find.byType(KeyboardShortcutsStep), matching: find.byType(Scrollable)),
    );
    await tester.tap(find.byKey(KeyboardShortcutsStep.restoreKey));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testOnMac('resetting the wallet puts the default shortcuts back', (tester) async {
    await _openShortcuts(tester);
    await _record(tester, AppCommand.send);
    await _press(tester, LogicalKeyboardKey.backspace);
    final container = ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

    await container.read(walletPresenceProvider.notifier).wipeWallet();
    await tester.pumpAndSettle();

    expect(container.read(shortcutBindingsProvider).bindings[AppCommand.send], isNotNull);
  });
}
