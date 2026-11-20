import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// More about [child], shown while the pointer rests on it, as a macOS
/// popover: after [openAfter] of hover [popover] opens under it (above it,
/// where there is no room below), its arrow pointing [anchorX] into it. The
/// pointer can move into the popover, to use what it holds; it closes
/// [closeAfter] after the pointer has left both. It fades in, at once when
/// the system asks for less motion.
class HoverPopover extends StatefulWidget {
  const HoverPopover({super.key, required this.child, required this.popover, this.anchorX = 0});

  final Widget child;
  final Widget popover;

  /// How far into [child], from its left, the arrow points.
  final double anchorX;

  static const openAfter = Duration(milliseconds: 500);
  static const closeAfter = Duration(milliseconds: 200);
  static const fadeIn = Duration(milliseconds: 120);

  static const arrowKey = Key('hover-popover-arrow');
  static const boxKey = Key('hover-popover');
  static const fadeKey = Key('hover-popover-fade');

  @override
  State<HoverPopover> createState() => _HoverPopoverState();
}

class _HoverPopoverState extends State<HoverPopover> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  late final _fade = AnimationController(vsync: this, duration: HoverPopover.fadeIn);

  /// Whether the arrow points up, at a target above the popover: set as the
  /// popover is placed, before it is painted.
  final _pointsUp = ValueNotifier(true);
  Timer? _opening;
  Timer? _closing;
  bool _onChild = false;
  bool _onPopover = false;

  /// Where [HoverPopover.child] is in the overlay, as it was when the popover
  /// opened.
  Rect _target = Rect.zero;

  @override
  void dispose() {
    _opening?.cancel();
    _closing?.cancel();
    _fade.dispose();
    _pointsUp.dispose();
    super.dispose();
  }

  void _enterChild() {
    _onChild = true;
    _closing?.cancel();
    if (!_portal.isShowing) _opening ??= Timer(HoverPopover.openAfter, _open);
  }

  void _exitChild() {
    _onChild = false;
    _opening?.cancel();
    _opening = null;
    _closeSoon();
  }

  void _enterPopover() {
    _onPopover = true;
    _closing?.cancel();
  }

  void _exitPopover() {
    _onPopover = false;
    _closeSoon();
  }

  void _closeSoon() {
    if (!_portal.isShowing) return;
    _closing?.cancel();
    _closing = Timer(HoverPopover.closeAfter, () {
      if (!mounted || _onChild || _onPopover) return;
      _portal.hide();
      _fade.value = 0;
    });
  }

  void _open() {
    _opening = null;
    if (!mounted || !_onChild) return;
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    _target = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    _portal.show();
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = 1;
    } else {
      _fade.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) => FadeTransition(
        key: HoverPopover.fadeKey,
        opacity: _fade,
        child: CustomMultiChildLayout(
          delegate: _Placement(
            target: _target,
            anchorX: widget.anchorX,
            onPlaced: (isBelow) => _pointsUp.value = isBelow,
          ),
          children: [
            LayoutId(
              id: _Part.box,
              child: MouseRegion(
                onEnter: (_) => _enterPopover(),
                onExit: (_) => _exitPopover(),
                child: _Box(key: HoverPopover.boxKey, child: widget.popover),
              ),
            ),
            LayoutId(
              id: _Part.arrow,
              child: CustomPaint(
                key: HoverPopover.arrowKey,
                painter: _Arrow(fill: colors.bgSurface2, edge: colors.borderEmphasis, pointsUp: _pointsUp),
              ),
            ),
          ],
        ),
      ),
      child: MouseRegion(onEnter: (_) => _enterChild(), onExit: (_) => _exitChild(), child: widget.child),
    );
  }
}

enum _Part { box, arrow }

/// The arrow's size, and how far it stands in from the box's left edge.
const _arrowSize = Size(18, 9);
const double _arrowInset = 17;

/// The space between the popover and its target, and the window's edges.
const double _gap = 4;
const double _margin = 8;

/// Places the popover under its target, or above it where there is no room
/// below, its arrow pointing [anchorX] into the target and its box kept
/// within the window. Where it goes is told to [onPlaced]: true under the
/// target.
class _Placement extends MultiChildLayoutDelegate {
  _Placement({required this.target, required this.anchorX, required this.onPlaced});

  final Rect target;
  final double anchorX;
  final ValueChanged<bool> onPlaced;

  @override
  void performLayout(Size size) {
    final box = layoutChild(_Part.box, BoxConstraints.loose(Size(size.width - 2 * _margin, size.height - 2 * _margin)));
    final below = size.height - target.bottom - _margin;
    final above = target.top - _margin;
    final needed = _gap + _arrowSize.height + box.height;
    final isBelow = below >= needed || below >= above;

    final tip = target.left + anchorX;
    final left = (tip - _arrowInset - _arrowSize.width / 2).clamp(_margin, size.width - _margin - box.width).toDouble();
    final arrowLeft = (tip - _arrowSize.width / 2)
        .clamp(left + 6, math.max(left + 6, left + box.width - 6 - _arrowSize.width))
        .toDouble();

    final arrowTop = isBelow ? target.bottom + _gap : target.top - _gap - _arrowSize.height;
    // The box's edge runs under the arrow's base, so the two read as one.
    final boxTop = isBelow ? arrowTop + _arrowSize.height - 1 : arrowTop + 1 - box.height;
    positionChild(_Part.box, Offset(left, boxTop));

    layoutChild(_Part.arrow, BoxConstraints.tight(_arrowSize));
    positionChild(_Part.arrow, Offset(arrowLeft, arrowTop));
    onPlaced(isBelow);
  }

  @override
  bool shouldRelayout(_Placement old) => old.target != target || old.anchorX != anchorX;
}

/// The popover's surface: the app's menus' raised one, its hairline edge
/// and shadow.
class _Box extends StatelessWidget {
  const _Box({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final radius = context.radiusV3.smBorder;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.borderEmphasis),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSurface2,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.5), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

/// The arrow, in the box's colours, pointing up at a target above it or down
/// at one below, as [pointsUp] says. Its base is left open, to join the box.
class _Arrow extends CustomPainter {
  _Arrow({required this.fill, required this.edge, required this.pointsUp}) : super(repaint: pointsUp);

  final Color fill;
  final Color edge;
  final ValueListenable<bool> pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final (base, tip) = pointsUp.value ? (size.height, 0.0) : (0.0, size.height);
    final outline = Path()
      ..moveTo(0, base)
      ..lineTo(size.width / 2, tip)
      ..lineTo(size.width, base);
    canvas.drawPath(Path.from(outline)..close(), Paint()..color = fill);
    canvas.drawPath(
      outline,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Arrow old) => old.fill != fill || old.edge != edge || old.pointsUp != pointsUp;
}
