import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_desktop_wallet/models/shortcut_bindings.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';

/// One item of a context menu.
class ContextMenuItem {
  const ContextMenuItem(this.label, {required this.onSelected, this.keys, this.isDestructive = false});

  final String label;
  final VoidCallback onSelected;

  /// The item's shortcut, shown at its end; the menu bar answers it.
  final KeyCombo? keys;

  /// Drawn in ember: the item removes or ends something.
  final bool isDestructive;
}

/// Opens a context menu of [items] where [child] is right-clicked, or, on
/// the Mac, Control-clicked, as the HIG has every app do.
///
/// A null item is a separator between groups. The items are asked for when
/// the menu opens, so they are what holds at that moment.
///
/// A Control-click is also a click to [child]'s own tap handler, which must
/// ignore it while [isControlClick] is true.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({super.key, required this.items, required this.child});

  final List<ContextMenuItem?> Function() items;
  final Widget child;

  static const menuKey = Key('context-menu');

  /// The closest the menu comes to the window's edges.
  static const double windowMargin = 6;

  static bool _isControlClick = false;

  /// Whether the click being handled opened a context menu (a Control-click
  /// on the Mac) rather than being a click.
  static bool get isControlClick => _isControlClick;

  void _onPointerDown(BuildContext context, PointerDownEvent event) {
    final isMacControlClick =
        defaultTargetPlatform == TargetPlatform.macOS &&
        event.buttons == kPrimaryButton &&
        HardwareKeyboard.instance.isControlPressed;
    _isControlClick = isMacControlClick;
    if (event.buttons == kSecondaryButton || isMacControlClick) unawaited(_open(context, event.position));
  }

  /// The click's own tap is answered after this, in the same event, so the
  /// mark is cleared once the event is done.
  void _onPointerEnd() {
    if (_isControlClick) scheduleMicrotask(() => _isControlClick = false);
  }

  Future<void> _open(BuildContext context, Offset position) async {
    final entries = items();
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final chosen = await navigator.push<ContextMenuItem>(
      _ContextMenuRoute(
        entries: entries,
        position: overlay.globalToLocal(position),
        theme: Theme.of(context),
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
    );
    chosen?.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _onPointerDown(context, event),
      onPointerUp: (_) => _onPointerEnd(),
      onPointerCancel: (_) => _onPointerEnd(),
      child: child,
    );
  }
}

/// The open menu, over everything, closed by a click outside or Escape.
class _ContextMenuRoute extends PopupRoute<ContextMenuItem> {
  _ContextMenuRoute({required this.entries, required this.position, required this.theme, required this.barrierLabel});

  final List<ContextMenuItem?> entries;
  final Offset position;
  final ThemeData theme;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  // macOS shows its menus at once, and fades them out.
  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return Theme(
      data: theme,
      // A route of its own has no text style above it; the menu sets one.
      child: DefaultTextStyle(
        style: theme.textTheme.bodyMedium ?? const TextStyle(),
        child: CustomSingleChildLayout(
          delegate: _ContextMenuLayout(position),
          child: _ContextMenu(entries: entries),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(opacity: animation, child: child);
}

/// Places the menu's top left corner at the pointer, then moves it inside
/// the window if it would leave it.
class _ContextMenuLayout extends SingleChildLayoutDelegate {
  _ContextMenuLayout(this.position);

  final Offset position;

  static const _margin = ContextMenuRegion.windowMargin;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    position.dx.clamp(_margin, math.max(_margin, size.width - childSize.width - _margin)),
    position.dy.clamp(_margin, math.max(_margin, size.height - childSize.height - _margin)),
  );

  @override
  bool shouldRelayout(_ContextMenuLayout oldDelegate) => position != oldDelegate.position;
}

class _ContextMenu extends StatefulWidget {
  const _ContextMenu({required this.entries});

  final List<ContextMenuItem?> entries;

  @override
  State<_ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<_ContextMenu> {
  /// The items, without the separators: what the arrow keys walk.
  late final List<ContextMenuItem> _items = widget.entries.whereType<ContextMenuItem>().toList();

  /// The item the pointer or the arrow keys are on, if any.
  int? _highlighted;

  void _choose(int index) => Navigator.of(context).pop(_items[index]);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final last = _items.length - 1;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlighted = math.min((_highlighted ?? -1) + 1, last));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlighted = math.max((_highlighted ?? last + 1) - 1, 0));
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      final highlighted = _highlighted;
      if (highlighted != null) _choose(highlighted);
    } else if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    var index = -1;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: MenuPanel(
        key: ContextMenuRegion.menuKey,
        children: [
          for (final entry in widget.entries)
            if (entry == null) const MenuPanelSeparator() else _row(entry, ++index),
        ],
      ),
    );
  }

  Widget _row(ContextMenuItem item, int index) {
    return MouseRegion(
      onEnter: (_) => setState(() => _highlighted = index),
      onExit: (_) => setState(() => _highlighted = _highlighted == index ? null : _highlighted),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(index),
        child: MenuPanelRow(
          label: item.label,
          keys: item.keys,
          isDestructive: item.isDestructive,
          isHighlighted: index == _highlighted,
        ),
      ),
    );
  }
}
