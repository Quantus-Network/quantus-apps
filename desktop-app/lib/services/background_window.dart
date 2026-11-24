import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';

/// The items of the menu bar icon, there while the window is closed with work
/// under way.
typedef StatusItemLabels = ({String openLabel, String quitLabel});

/// The native side of running with the window closed, on the channel of
/// [WindowChrome]. Served by `MainFlutterWindow.swift`; only macOS has it.
class BackgroundWindow {
  const BackgroundWindow();

  /// Tells the window what its menu bar icon's items say. Until it has been
  /// told, the app is not ready to be asked about closing, and closing the
  /// window quits it.
  Future<void> configure(StatusItemLabels labels) => WindowChrome.channel.invokeMethod<void>('setStatusItemLabels', {
    'openLabel': labels.openLabel,
    'quitLabel': labels.quitLabel,
  });

  /// Takes the window off the screen and leaves the app running.
  Future<void> hide() => WindowChrome.channel.invokeMethod<void>('hideWindow');

  /// Asks macOS not to slow the app down (App Nap) while [isAwake].
  Future<void> setStayAwake(bool isAwake) =>
      WindowChrome.channel.invokeMethod<void>('setStayAwake', {'isAwake': isAwake});

  /// Shows the window again, in front of the other apps' windows.
  Future<void> bringToFront() => const WindowChrome().bringToFront();

  /// Answers the window: [onWillClose] when the person closed it, which it
  /// waits for and which says whether to hide (true) or to close and quit
  /// (false), and [onDidOpen] when it came back.
  void listen({required Future<bool> Function() onWillClose, required VoidCallback onDidOpen}) {
    WindowChrome.channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'windowWillClose':
          return onWillClose();
        case 'windowDidOpen':
          onDidOpen();
        default:
          throw MissingPluginException('The app does not answer ${call.method}');
      }
    });
  }

  void stopListening() => WindowChrome.channel.setMethodCallHandler(null);
}

final backgroundWindowProvider = Provider<BackgroundWindow>((ref) => const BackgroundWindow());
