import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';

/// What the native window is to do while the app runs: whether closing it
/// leaves the app running, and the menu bar icon's items.
typedef BackgroundModeRequest = ({bool keepRunning, String openLabel, String quitLabel});

/// The native side of running with the window closed, on the channel of
/// [WindowChrome]. Served by `MainFlutterWindow.swift`; only macOS has it.
class BackgroundWindow {
  const BackgroundWindow();

  /// Tells the window what to do when it is closed. Until it has been told,
  /// closing it quits the app.
  Future<void> configure(BackgroundModeRequest request) => WindowChrome.channel.invokeMethod<void>(
    'setBackgroundMode',
    {'keepRunning': request.keepRunning, 'openLabel': request.openLabel, 'quitLabel': request.quitLabel},
  );

  /// Takes the window off the screen and leaves the app running.
  Future<void> hide() => WindowChrome.channel.invokeMethod<void>('hideWindow');

  /// Asks macOS not to slow the app down (App Nap) while [isAwake].
  Future<void> setStayAwake(bool isAwake) =>
      WindowChrome.channel.invokeMethod<void>('setStayAwake', {'isAwake': isAwake});

  /// Shows the window again, in front of the other apps' windows.
  Future<void> bringToFront() => const WindowChrome().bringToFront();

  /// Answers the window: [onWillClose] when the person closed it, which it
  /// waits for before leaving the screen, and [onDidOpen] when it came back.
  void listen({required Future<void> Function() onWillClose, required VoidCallback onDidOpen}) {
    WindowChrome.channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'windowWillClose':
          await onWillClose();
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
