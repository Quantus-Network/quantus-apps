import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';

/// Empty space that behaves like a title bar: dragging it moves the window
/// and double-clicking it zooms or minimises.
///
/// Put it behind a header's controls, not around them, so a press on a
/// control never reaches it.
class WindowDragArea extends StatelessWidget {
  const WindowDragArea({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => unawaited(const WindowChrome().startDrag()),
      onDoubleTap: () => unawaited(const WindowChrome().titleBarDoubleClick()),
    );
  }
}
