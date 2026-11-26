import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/status_item_swaps.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';

/// The items of the menu bar icon, there while the window is closed with work
/// under way or a swap is in progress.
typedef StatusItemLabels = ({String openLabel, String quitLabel});

/// The native side of running with the window closed, and of the menu bar
/// icon, on the channel of [WindowChrome]. Served by `MainFlutterWindow.swift`;
/// only macOS has it.
class BackgroundWindow {
  const BackgroundWindow();

  /// Tells the window what its menu bar icon's items say. Until it has been
  /// told, the app is not ready to be asked about closing, and closing the
  /// window quits it.
  Future<void> configure(StatusItemLabels labels) => WindowChrome.channel.invokeMethod<void>('setStatusItemLabels', {
    'openLabel': labels.openLabel,
    'quitLabel': labels.quitLabel,
  });

  /// Tells the menu bar icon the swaps in progress, which it shows whether
  /// the window is open or not.
  Future<void> setSwaps(StatusItemSwaps swaps) => WindowChrome.channel.invokeMethod<void>('setStatusItemSwaps', {
    'title': swaps.title,
    'swaps': [
      for (final swap in swaps.swaps)
        {
          'swapId': swap.swapId,
          'accountId': swap.accountId,
          'label': swap.label,
          'steps': swap.steps,
          'current': swap.current,
        },
    ],
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
  /// (false), [onDidOpen] when it came back, and [onOpenSwap] when a swap was
  /// picked from the menu bar icon's menu.
  void listen({
    required Future<bool> Function() onWillClose,
    required VoidCallback onDidOpen,
    required void Function({required String swapId, required String accountId}) onOpenSwap,
  }) {
    WindowChrome.channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'windowWillClose':
          return onWillClose();
        case 'windowDidOpen':
          onDidOpen();
        case 'openSwap':
          final arguments = call.arguments as Map<Object?, Object?>;
          onOpenSwap(swapId: arguments['swapId']! as String, accountId: arguments['accountId']! as String);
        default:
          throw MissingPluginException('The app does not answer ${call.method}');
      }
    });
  }

  void stopListening() => WindowChrome.channel.setMethodCallHandler(null);
}

final backgroundWindowProvider = Provider<BackgroundWindow>((ref) => const BackgroundWindow());
