import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The gap between two panels, which resizes the one at its left. Over it
/// the pointer becomes the resize arrows and a line shows in the gap, as it
/// does while it is dragged.
///
/// A drag sets the width to what it was when the drag began plus how far
/// the pointer has gone, so after the width stopped at a limit, the edge
/// moves again only once the pointer is back over it.
class PanelResizeHandle extends StatefulWidget {
  const PanelResizeHandle({super.key, required this.width, required this.onResize, required this.onResizeEnd});

  /// The width of the panel it resizes, now.
  final double width;

  /// Asks for the panel's width to be this, as the pointer moves.
  final ValueChanged<double> onResize;

  /// The drag is over: the width is what it will stay.
  final VoidCallback onResizeEnd;

  /// The line in the gap.
  static const lineKey = Key('panel-resize-line');

  @override
  State<PanelResizeHandle> createState() => _PanelResizeHandleState();
}

class _PanelResizeHandleState extends State<PanelResizeHandle> {
  bool _isHovered = false;
  bool _isDragging = false;
  double _startWidth = 0;
  double _startX = 0;

  void _end() {
    if (!_isDragging) return;
    setState(() => _isDragging = false);
    widget.onResizeEnd();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Measured from where the button went down, so no part of the drag
        // is lost to the slop.
        dragStartBehavior: DragStartBehavior.down,
        onHorizontalDragStart: (details) => setState(() {
          _isDragging = true;
          _startWidth = widget.width;
          _startX = details.globalPosition.dx;
        }),
        onHorizontalDragUpdate: (details) => widget.onResize(_startWidth + details.globalPosition.dx - _startX),
        onHorizontalDragEnd: (_) => _end(),
        onHorizontalDragCancel: _end,
        child: SizedBox(
          width: Panel.gap,
          child: _isHovered || _isDragging
              ? Center(
                  child: Container(
                    key: PanelResizeHandle.lineKey,
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colorsV3.textMuted.useOpacity(0.7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
