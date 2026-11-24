import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One item of a context menu.
class ContextMenuItem {
  const ContextMenuItem(this.label, {required VoidCallback this.onSelected, this.isDestructive = false})
    : submenu = null;

  /// An item that opens [items] beside it, and does nothing itself.
  const ContextMenuItem.submenu(this.label, {required List<ContextMenuItem> items})
    : submenu = items,
      onSelected = null,
      isDestructive = false;

  final String label;

  /// What choosing the item does; null on an item with a [submenu].
  final VoidCallback? onSelected;

  /// What the item opens beside it, if it does.
  final List<ContextMenuItem>? submenu;

  /// Drawn in ember: the item removes or ends something.
  final bool isDestructive;
}

/// Pulls down a menu of [items] from the control at [anchor], in global
/// coordinates: under it, or above it when there is no room below, as at the
/// foot of the window. A null item is a separator.
Future<void> showPullDownMenu(
  BuildContext context, {
  required Rect anchor,
  required List<ContextMenuItem?> items,
}) async {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final chosen = await navigator.push<ContextMenuItem>(
    _ContextMenuRoute(
      entries: items,
      layout: _PullDownLayout(overlay.globalToLocal(anchor.topLeft) & anchor.size),
      theme: Theme.of(context),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ),
  );
  chosen?.onSelected?.call();
}

/// Opens a context menu of [items] where [child] is right-clicked, or, on
/// the Mac, Control-clicked, as the HIG has every app do. Its items show no
/// shortcuts: the HIG keeps those to the app's main menus.
///
/// A null item is a separator between groups. The items are asked for when
/// the menu opens, so they are what holds at that moment.
///
/// A Control-click is also a click to [child]'s own tap handler, which must
/// ignore it while [isControlClick] is true. While the menu is open, [child]
/// is ringed in the accent, as macOS rings the item a menu acts on.
class ContextMenuRegion extends StatefulWidget {
  const ContextMenuRegion({super.key, required this.items, required this.child});

  final List<ContextMenuItem?> Function() items;
  final Widget child;

  static const menuKey = Key('context-menu');
  static const submenuKey = Key('context-submenu');
  static const ringKey = Key('context-menu-ring');

  /// The closest the menu comes to the window's edges.
  static const double windowMargin = 6;

  /// How long the pointer rests on another item before an open submenu gives
  /// way to it: a pointer heading for the submenu may cross that item.
  static const submenuPause = Duration(milliseconds: 250);

  static bool _isControlClick = false;

  /// Whether the click being handled opened a context menu (a Control-click
  /// on the Mac) rather than being a click.
  static bool get isControlClick => _isControlClick;

  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

class _ContextMenuRegionState extends State<ContextMenuRegion> {
  bool _isOpen = false;

  void _onPointerDown(PointerDownEvent event) {
    final isMacControlClick =
        defaultTargetPlatform == TargetPlatform.macOS &&
        event.buttons == kPrimaryButton &&
        HardwareKeyboard.instance.isControlPressed;
    ContextMenuRegion._isControlClick = isMacControlClick;
    if (event.buttons == kSecondaryButton || isMacControlClick) unawaited(_open(event.position));
  }

  /// The click's own tap is answered after this, in the same event, so the
  /// mark is cleared once the event is done.
  void _onPointerEnd() {
    if (ContextMenuRegion._isControlClick) scheduleMicrotask(() => ContextMenuRegion._isControlClick = false);
  }

  Future<void> _open(Offset position) async {
    if (_isOpen) return;
    final entries = widget.items();
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    setState(() => _isOpen = true);
    final chosen = await navigator.push<ContextMenuItem>(
      _ContextMenuRoute(
        entries: entries,
        layout: _ContextMenuLayout(overlay.globalToLocal(position)),
        theme: Theme.of(context),
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
    );
    if (mounted) setState(() => _isOpen = false);
    chosen?.onSelected?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: (_) => _onPointerEnd(),
      onPointerCancel: (_) => _onPointerEnd(),
      // The child keeps the size it is given: a wallet heading is right-clicked
      // across its width, and ringed so, not only over its name.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_isOpen)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  key: ContextMenuRegion.ringKey,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colorsV3.accentFlare, width: 2),
                    borderRadius: context.radiusV3.smBorder,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The open menu, over everything, closed by a click outside or Escape.
class _ContextMenuRoute extends PopupRoute<ContextMenuItem> {
  _ContextMenuRoute({required this.entries, required this.layout, required this.theme, required this.barrierLabel});

  final List<ContextMenuItem?> entries;

  /// Where the menu sits in the window.
  final SingleChildLayoutDelegate layout;
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
        child: _ContextMenu(entries: entries, layout: layout),
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

/// Places a pull-down menu under its control, or above it when it would not
/// fit below, inside the window.
class _PullDownLayout extends SingleChildLayoutDelegate {
  _PullDownLayout(this.anchor);

  final Rect anchor;

  static const _margin = ContextMenuRegion.windowMargin;

  /// The space between the control and the menu.
  static const double _gap = 4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final below = anchor.bottom + _gap;
    final top = below + childSize.height <= size.height - _margin ? below : anchor.top - _gap - childSize.height;
    return Offset(
      anchor.left.clamp(_margin, math.max(_margin, size.width - childSize.width - _margin)),
      top.clamp(_margin, math.max(_margin, size.height - childSize.height - _margin)),
    );
  }

  @override
  bool shouldRelayout(_PullDownLayout oldDelegate) => anchor != oldDelegate.anchor;
}

/// Places a submenu beside the row it hangs from: on its right, or on its
/// left when it would leave the window, its first row level with that row.
class _SubmenuLayout extends SingleChildLayoutDelegate {
  _SubmenuLayout(this.anchor);

  final Rect anchor;

  static const _margin = ContextMenuRegion.windowMargin;

  /// How far a submenu lies over the menu it comes from, as macOS draws it.
  static const double _overlap = 2;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(const EdgeInsets.all(_margin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final onRight = anchor.right - _overlap;
    final left = onRight + childSize.width <= size.width - _margin ? onRight : anchor.left + _overlap - childSize.width;
    return Offset(
      left.clamp(_margin, math.max(_margin, size.width - childSize.width - _margin)),
      (anchor.top - MenuPanel.padding).clamp(_margin, math.max(_margin, size.height - childSize.height - _margin)),
    );
  }

  @override
  bool shouldRelayout(_SubmenuLayout oldDelegate) => anchor != oldDelegate.anchor;
}

class _ContextMenu extends StatefulWidget {
  const _ContextMenu({required this.entries, required this.layout});

  final List<ContextMenuItem?> entries;
  final SingleChildLayoutDelegate layout;

  @override
  State<_ContextMenu> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<_ContextMenu> {
  /// The items, without the separators: what the arrow keys walk.
  late final List<ContextMenuItem> _items = widget.entries.whereType<ContextMenuItem>().toList();

  /// The item the pointer or the arrow keys are on, if any.
  int? _highlighted;

  /// The item whose submenu is open, and where that item is.
  int? _submenuOf;
  Rect? _submenuAnchor;

  /// The submenu's item the pointer or the arrow keys are on, if any.
  int? _submenuHighlighted;

  /// Whether the arrow keys are walking the submenu rather than the menu.
  bool _keysInSubmenu = false;

  final _rowKeys = <int, GlobalKey>{};
  final _submenuRowKeys = <int, GlobalKey>{};

  /// Counts down [ContextMenuRegion.submenuPause] while the pointer is on
  /// [_pausedOn], another item than the one whose submenu is open.
  Timer? _pause;
  int? _pausedOn;

  List<ContextMenuItem>? get _submenu => switch (_submenuOf) {
    final index? => _items[index].submenu,
    null => null,
  };

  @override
  void dispose() {
    _pause?.cancel();
    super.dispose();
  }

  void _cancelPause() {
    _pause?.cancel();
    _pause = null;
    _pausedOn = null;
  }

  void _choose(ContextMenuItem item) {
    _cancelPause();
    Navigator.of(context).pop(item);
  }

  /// The pointer came onto the item at [index]. With another item's submenu
  /// open it may be on its way there, so the item waits for it to rest.
  void _onRowEntered(int index) {
    _cancelPause();
    final open = _submenuOf;
    if (open == null || open == index) return _showRow(index);
    _pausedOn = index;
    _pause = Timer(ContextMenuRegion.submenuPause, () {
      _cancelPause();
      if (mounted) _showRow(index);
    });
  }

  void _showRow(int index) {
    if (_items[index].submenu != null) {
      _openSubmenu(index);
    } else {
      setState(() {
        _highlighted = index;
        _closeSubmenu();
      });
    }
  }

  void _openSubmenu(int index, {bool withKeys = false}) {
    _cancelPause();
    final page = context.findRenderObject()! as RenderBox;
    final row = _rowKeys[index]!.currentContext!.findRenderObject()! as RenderBox;
    setState(() {
      if (_submenuOf != index) _submenuRowKeys.clear();
      _highlighted = index;
      _submenuOf = index;
      _submenuAnchor = row.localToGlobal(Offset.zero, ancestor: page) & row.size;
      _keysInSubmenu = withKeys;
      _submenuHighlighted = withKeys ? 0 : null;
    });
  }

  /// To be called inside [setState].
  void _closeSubmenu() {
    _cancelPause();
    _submenuOf = null;
    _submenuAnchor = null;
    _submenuHighlighted = null;
    _keysInSubmenu = false;
    _submenuRowKeys.clear();
  }

  /// Keeps the submenu's item the keys reached in view, in a long submenu.
  void _reveal(int index, ScrollPositionAlignmentPolicy policy) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _submenuRowKeys[index]?.currentContext;
      if (row != null) unawaited(Scrollable.ensureVisible(row, alignmentPolicy: policy));
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isChoose =
        key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space;
    final submenu = _submenu;
    if (_keysInSubmenu && submenu != null) return _onSubmenuKey(key, isChoose, submenu);

    final last = _items.length - 1;
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlighted = math.min((_highlighted ?? -1) + 1, last);
        _closeSubmenu();
      });
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlighted = math.max((_highlighted ?? last + 1) - 1, 0);
        _closeSubmenu();
      });
    } else if (isChoose || key == LogicalKeyboardKey.arrowRight) {
      final highlighted = _highlighted;
      if (highlighted != null && _items[highlighted].submenu != null) {
        _openSubmenu(highlighted, withKeys: true);
      } else if (!isChoose) {
        return KeyEventResult.ignored;
      } else if (highlighted != null) {
        _choose(_items[highlighted]);
      }
    } else if (key == LogicalKeyboardKey.escape) {
      if (_submenuOf != null) {
        setState(_closeSubmenu);
      } else {
        Navigator.of(context).pop();
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _onSubmenuKey(LogicalKeyboardKey key, bool isChoose, List<ContextMenuItem> submenu) {
    final last = submenu.length - 1;
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = math.min((_submenuHighlighted ?? -1) + 1, last);
      setState(() => _submenuHighlighted = next);
      _reveal(next, ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final next = math.max((_submenuHighlighted ?? last + 1) - 1, 0);
      setState(() => _submenuHighlighted = next);
      _reveal(next, ScrollPositionAlignmentPolicy.keepVisibleAtStart);
    } else if (isChoose) {
      final highlighted = _submenuHighlighted;
      if (highlighted != null) _choose(submenu[highlighted]);
    } else if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.escape) {
      setState(_closeSubmenu);
    } else if (key != LogicalKeyboardKey.arrowRight) {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    var index = -1;
    final submenu = _submenu;
    final anchor = _submenuAnchor;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomSingleChildLayout(
            delegate: widget.layout,
            child: MenuPanel(
              key: ContextMenuRegion.menuKey,
              children: [
                for (final entry in widget.entries)
                  if (entry == null) const MenuPanelSeparator() else _row(entry, ++index),
              ],
            ),
          ),
          if (submenu != null && anchor != null)
            CustomSingleChildLayout(
              delegate: _SubmenuLayout(anchor),
              child: MenuPanel(
                key: ContextMenuRegion.submenuKey,
                scrolls: true,
                children: [for (final (row, item) in submenu.indexed) _submenuRow(item, row)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(ContextMenuItem item, int index) {
    final opensSubmenu = item.submenu != null;
    return MouseRegion(
      key: opensSubmenu ? _rowKeys.putIfAbsent(index, GlobalKey.new) : null,
      onEnter: (_) => _onRowEntered(index),
      // The item stays lit while its submenu is open: the pointer is on its
      // way there.
      onExit: (_) => setState(() {
        if (_pausedOn == index) _cancelPause();
        if (_highlighted == index && _submenuOf != index) _highlighted = null;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => opensSubmenu ? _openSubmenu(index) : _choose(item),
        child: MenuPanelRow(
          label: item.label,
          isDestructive: item.isDestructive,
          isHighlighted: index == _highlighted,
          hasSubmenu: opensSubmenu,
        ),
      ),
    );
  }

  Widget _submenuRow(ContextMenuItem item, int index) {
    return MouseRegion(
      key: _submenuRowKeys.putIfAbsent(index, GlobalKey.new),
      onEnter: (_) => setState(() {
        _keysInSubmenu = true;
        _submenuHighlighted = index;
      }),
      onExit: (_) => setState(() {
        if (_submenuHighlighted == index) _submenuHighlighted = null;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _choose(item),
        child: MenuPanelRow(label: item.label, isHighlighted: index == _submenuHighlighted),
      ),
    );
  }
}
