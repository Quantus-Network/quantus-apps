import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The key every command of the menus answers to, in one place.
///
/// A command key is ⌘ on macOS ([useCommandKey]) and Ctrl elsewhere. Walking
/// the sidebar is Ctrl+Tab on every platform, as it is for tabs.
class AppShortcuts {
  const AppShortcuts({required this.useCommandKey});

  final bool useCommandKey;

  /// The keys of the first accounts in the sidebar, in its order.
  static const _accountKeys = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ];

  SingleActivator _command(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: useCommandKey, control: !useCommandKey);

  SingleActivator get settings => _command(LogicalKeyboardKey.comma);
  SingleActivator get closeWindow => _command(LogicalKeyboardKey.keyW);
  SingleActivator get toggleSidebar => _command(LogicalKeyboardKey.keyB);
  SingleActivator get addAccount => _command(LogicalKeyboardKey.keyN);
  SingleActivator get receive => _command(LogicalKeyboardKey.keyR);
  SingleActivator get send => _command(LogicalKeyboardKey.keyS);

  SingleActivator get nextSidebarItem => const SingleActivator(LogicalKeyboardKey.tab, control: true);
  SingleActivator get previousSidebarItem => const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true);

  /// The shortcut of the account at [index] in the sidebar's order, or null
  /// past the ninth: there are nine digits to give.
  SingleActivator? account(int index) => index < _accountKeys.length ? _command(_accountKeys[index]) : null;
}
