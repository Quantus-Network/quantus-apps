import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shows [menus] the way the platform expects: in the system's menu bar on
/// macOS ([useNativeMenuBar]), and in a bar across the top of the window
/// elsewhere, where this widget also listens for the menus' shortcuts.
class AppMenuBar extends StatelessWidget {
  const AppMenuBar({
    super.key,
    required this.menus,
    required this.resolveMenus,
    required this.useNativeMenuBar,
    required this.child,
  });

  /// The menus as they are drawn.
  final List<PlatformMenu> menus;

  /// The menus as they are when it is called. A key can arrive before the
  /// frame that redraws [menus], so the bar in the window answers a key from
  /// these: an item that the key before it made available is not missed.
  final List<PlatformMenu> Function() resolveMenus;

  final bool useNativeMenuBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (useNativeMenuBar) return PlatformMenuBar(menus: menus, child: child);

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (_, event) => _onKey(event),
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

  /// Selects the item [event] is the shortcut of, if it is available now.
  /// The key of an unavailable item is left for whoever else listens.
  KeyEventResult _onKey(KeyEvent event) {
    for (final item in resolveMenus().expand(_leavesOf)) {
      final onSelected = item.onSelected;
      if (onSelected == null) continue;
      if (item.shortcut?.accepts(event, HardwareKeyboard.instance) ?? false) {
        onSelected();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
