import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether the app draws its header where the window's title bar would be.
/// True on macOS, where the traffic lights sit on that header; Windows and
/// Linux keep their own title bar above the app.
bool get drawsOverTitleBar => defaultTargetPlatform == TargetPlatform.macOS;

/// Width the traffic lights take at the left of the header, with the gap
/// after them. `MainFlutterWindow.swift` puts the buttons 20pt in and 20pt
/// apart, so the last one ends at 74pt.
const double trafficLightsInset = 84;

/// Height of the header row. `MainFlutterWindow.swift` centres the traffic
/// lights in a strip of this height, so the two must change together.
const double shellHeaderHeight = 52;

/// Asks the macOS window to do what its title bar would have done, now that
/// the app's header covers it. Served by `MainFlutterWindow.swift`.
class WindowChrome {
  const WindowChrome();

  static const channel = MethodChannel('com.quantus.desktop-wallet/window');

  /// Hands the mouse press under way to the system as a window drag.
  Future<void> startDrag() => channel.invokeMethod<void>('startDrag');

  /// Zooms or minimises the window, whichever the system is set to do for a
  /// double-click on a title bar.
  Future<void> titleBarDoubleClick() => channel.invokeMethod<void>('titleBarDoubleClick');
}
