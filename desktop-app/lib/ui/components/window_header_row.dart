import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/components/window_drag_area.dart';

/// A row across the top of the window, or one side of it: [children] in a
/// row, over a drag area on macOS, where it takes the title bar's place.
///
/// Children that are not controls must ignore the pointer, so a press on them
/// falls through to the drag area behind.
class WindowHeaderRow extends StatelessWidget {
  const WindowHeaderRow({super.key, required this.leadsTheWindow, required this.children});

  /// Whether this row starts at the window's left edge, where the traffic
  /// lights are on macOS.
  final bool leadsTheWindow;
  final List<Widget> children;

  static const double _edgePadding = 16;

  @override
  Widget build(BuildContext context) {
    final start = leadsTheWindow && drawsOverTitleBar ? trafficLightsInset : _edgePadding;

    return SizedBox(
      height: shellHeaderHeight,
      child: Stack(
        children: [
          if (drawsOverTitleBar) const Positioned.fill(child: WindowDragArea()),
          // Filling the row's height is what centres the children in it.
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(left: start, right: _edgePadding),
              child: Row(spacing: 12, children: children),
            ),
          ),
        ],
      ),
    );
  }
}
