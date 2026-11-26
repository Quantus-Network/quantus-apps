import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_desktop_wallet/ui/components/menu_panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One choice of a [PopUpButton]: the [value] it stands for and its [label].
class PopUpItem<T> {
  const PopUpItem(this.value, this.label);

  final T value;
  final String label;
}

/// A pop-up button as macOS draws one: the current choice and an up-down
/// chevron. A click, or Space while it has the focus, opens a compact menu
/// with the current item laid over the button, so the choice stays where it
/// was. Up and Down move through the menu, Return or Space chooses, Escape
/// or a click outside closes it unchanged.
class PopUpButton<T> extends StatefulWidget {
  const PopUpButton({
    super.key,
    required this.semanticLabel,
    required this.items,
    required this.value,
    required this.onSelected,
  });

  /// What a screen reader calls the button; it reads the current item as
  /// its value.
  final String semanticLabel;
  final List<PopUpItem<T>> items;
  final T value;
  final ValueChanged<T> onSelected;

  static const menuKey = Key('pop-up-menu');
  static const checkmarkKey = MenuPanelRow.checkmarkKey;

  /// The height of a menu row.
  static const double rowHeight = MenuPanelRow.height;

  @override
  State<PopUpButton<T>> createState() => _PopUpButtonState<T>();
}

// The button's insets, which the menu lines its labels up with.
const double _buttonHeight = 26;
const double _buttonLabelInset = 10;

// The chevrons after the label, and the gap between them.
const double _chevronsSize = 11;
const double _chevronsGap = 8;

// The menu's insets, which are the shared menu panel's.
const double _menuPadding = MenuPanel.padding;

/// How far a row's label sits from the menu's left edge.
const double _menuLabelInset = MenuPanelRow.labelInset;

/// The closest the menu comes to the window's edges.
const double _windowMargin = 6;

class _PopUpButtonState<T> extends State<PopUpButton<T>> {
  bool _isFocused = false;
  bool _isOpen = false;

  int get _currentIndex => widget.items.indexWhere((item) => item.value == widget.value);

  Future<void> _open() async {
    if (_isOpen) return;
    final current = _currentIndex;
    if (current < 0) throw StateError('${widget.value} is not one of the pop-up button\'s items');

    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final button = context.findRenderObject()! as RenderBox;
    final buttonRect = button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;

    setState(() => _isOpen = true);
    final chosen = await navigator.push<int>(
      _PopUpMenuRoute(
        items: widget.items,
        currentIndex: current,
        buttonRect: buttonRect,
        theme: Theme.of(context),
        barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      ),
    );
    if (!mounted) return;
    setState(() => _isOpen = false);
    if (chosen != null) widget.onSelected(widget.items[chosen].value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final current = _currentIndex;
    final label = current < 0 ? '' : widget.items[current].label;

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      value: label,
      onTap: _open,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              borderRadius: context.radiusV3.smBorder,
              border: _isFocused
                  ? Border.all(color: colors.accentFlare.useOpacity(0.7), width: 2)
                  : Border.all(color: colors.borderHairline),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.textContent.useOpacity(_isOpen ? 0.12 : 0.08),
                borderRadius: context.radiusV3.smBorder,
              ),
              child: SizedBox(
                height: _buttonHeight,
                child: Padding(
                  padding: const EdgeInsets.only(left: _buttonLabelInset, right: 6),
                  // The label keeps room for the chevrons and is cut short to
                  // fit where the button has less room than it; a flexible
                  // label would fail in a row that sets no width.
                  child: Stack(
                    alignment: AlignmentDirectional.centerStart,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: _chevronsGap + _chevronsSize),
                        child: Text(
                          label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: text.body.copyWith(height: 1, color: colors.textContent),
                        ),
                      ),
                      PositionedDirectional(
                        end: 0,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Icon(
                            CupertinoIcons.chevron_up_chevron_down,
                            size: _chevronsSize,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The open menu, over everything, closed by a click outside or Escape.
class _PopUpMenuRoute<T> extends PopupRoute<int> {
  _PopUpMenuRoute({
    required this.items,
    required this.currentIndex,
    required this.buttonRect,
    required this.theme,
    required this.barrierLabel,
  });

  final List<PopUpItem<T>> items;
  final int currentIndex;
  final Rect buttonRect;
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
          delegate: _PopUpMenuLayout(buttonRect: buttonRect, currentIndex: currentIndex),
          child: _PopUpMenu(items: items, currentIndex: currentIndex, minWidth: buttonRect.width),
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

/// Places the menu so the current item's label lies on the button's label,
/// then moves it inside the window if it would leave it.
class _PopUpMenuLayout extends SingleChildLayoutDelegate {
  _PopUpMenuLayout({required this.buttonRect, required this.currentIndex});

  final Rect buttonRect;
  final int currentIndex;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(constraints.biggest).deflate(const EdgeInsets.all(_windowMargin));

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = buttonRect.left + _buttonLabelInset - _menuLabelInset;
    final top = buttonRect.center.dy - _menuPadding - currentIndex * PopUpButton.rowHeight - PopUpButton.rowHeight / 2;
    return Offset(
      left.clamp(_windowMargin, math.max(_windowMargin, size.width - childSize.width - _windowMargin)),
      top.clamp(_windowMargin, math.max(_windowMargin, size.height - childSize.height - _windowMargin)),
    );
  }

  @override
  bool shouldRelayout(_PopUpMenuLayout oldDelegate) =>
      buttonRect != oldDelegate.buttonRect || currentIndex != oldDelegate.currentIndex;
}

class _PopUpMenu<T> extends StatefulWidget {
  const _PopUpMenu({required this.items, required this.currentIndex, required this.minWidth});

  final List<PopUpItem<T>> items;
  final int currentIndex;
  final double minWidth;

  @override
  State<_PopUpMenu<T>> createState() => _PopUpMenuState<T>();
}

class _PopUpMenuState<T> extends State<_PopUpMenu<T>> {
  /// The row the pointer or the arrow keys are on, if any.
  late int? _highlighted = widget.currentIndex;

  /// Each row's key, to bring it into view where there are more rows than the
  /// window holds and the menu scrolls.
  late final List<GlobalKey> _rowKeys = [for (final _ in widget.items) GlobalKey()];

  @override
  void initState() {
    super.initState();
    // Laid out first: only then is it known whether the menu scrolls.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _centreCurrent();
    });
  }

  /// Scrolls the current item to the middle of the menu's view, as far as
  /// the rows go. Does nothing to a menu that shows every row.
  void _centreCurrent() {
    final row = _rowKeys[widget.currentIndex].currentContext;
    if (row == null) return;
    unawaited(Scrollable.ensureVisible(row, alignment: 0.5));
  }

  void _choose(int index) => Navigator.of(context).pop(index);

  /// The arrow keys move the highlight to [index], kept in view.
  void _highlight(int index, {required bool down}) {
    setState(() => _highlighted = index);
    final row = _rowKeys[index].currentContext;
    if (row == null) return;
    unawaited(
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: down
            ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd
            : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final last = widget.items.length - 1;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _highlight(math.min((_highlighted ?? -1) + 1, last), down: true);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _highlight(math.max((_highlighted ?? last + 1) - 1, 0), down: false);
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
    // Wide enough to cover the button from the menu's edge.
    final minWidth = widget.minWidth + _menuLabelInset - _buttonLabelInset;

    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: MenuPanel(
        key: PopUpButton.menuKey,
        minWidth: minWidth,
        scrolls: true,
        children: [
          for (final (index, item) in widget.items.indexed)
            MouseRegion(
              key: _rowKeys[index],
              onEnter: (_) => setState(() => _highlighted = index),
              onExit: (_) => setState(() => _highlighted = _highlighted == index ? null : _highlighted),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _choose(index),
                child: MenuPanelRow(
                  label: item.label,
                  isHighlighted: index == _highlighted,
                  isChecked: index == widget.currentIndex,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
