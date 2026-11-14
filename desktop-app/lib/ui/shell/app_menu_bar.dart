import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shows [menus] the way the platform expects: in the system's menu bar on
/// macOS ([useNativeMenuBar]), and in a bar across the top of the window
/// elsewhere, where this widget also listens for the menus' shortcuts.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({super.key, required this.menus, required this.useNativeMenuBar, required this.child});

  final List<PlatformMenu> menus;
  final bool useNativeMenuBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (useNativeMenuBar) return PlatformMenuBar(menus: menus, child: child);

    return CallbackShortcuts(
      bindings: {
        for (final item in menus.expand(_leavesOf))
          if (item.onSelected != null)
            if (item.shortcut case final ShortcutActivator shortcut) shortcut: item.onSelected!,
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: MenuBar(
                    children: [
                      for (final menu in menus) SubmenuButton(menuChildren: _buttonsOf(menu), child: Text(menu.label)),
                    ],
                  ),
                ),
              ],
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  /// The selectable items of [menu], with its groups opened up.
  static Iterable<PlatformMenuItem> _leavesOf(PlatformMenu menu) sync* {
    for (final entry in menu.menus) {
      if (entry is PlatformMenuItemGroup) {
        yield* entry.members;
      } else {
        yield entry;
      }
    }
  }

  /// [menu]'s items as buttons, with a divider between its groups.
  static List<Widget> _buttonsOf(PlatformMenu menu) {
    final buttons = <Widget>[];
    for (final entry in menu.menus) {
      if (entry is PlatformMenuItemGroup) {
        if (buttons.isNotEmpty) buttons.add(const MenuDivider());
        buttons.addAll(entry.members.map(_buttonFor));
      } else {
        buttons.add(_buttonFor(entry));
      }
    }
    return buttons;
  }

  static Widget _buttonFor(PlatformMenuItem item) {
    if (item is PlatformProvidedMenuItem || item is PlatformMenu) {
      throw UnsupportedError('The in-window menu bar cannot show "${item.label}" (${item.runtimeType}).');
    }
    return MenuItemButton(onPressed: item.onSelected, shortcut: item.shortcut, child: Text(item.label));
  }
}
