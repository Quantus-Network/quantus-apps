import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Puts a secret such as a recovery phrase on the clipboard for a short time
/// only, and asks the system's clipboard history not to keep it.
///
/// The native side marks the copy: on macOS as concealed and transient for
/// the clipboard managers that honour nspasteboard.org's markers, and for
/// this Mac only, so Universal Clipboard does not carry
/// it to other devices; on Windows with the formats that keep it out of
/// clipboard history and cloud sync. These are requests, not guarantees: a
/// clipboard manager may ignore them.
///
/// [lifetime] after the last copy the native side clears the clipboard, and
/// it does so again when the app quits, but only if the clipboard still
/// holds that copy, so a later copy of the user's own is left alone.
///
/// A copy that cannot be marked is not made at all; it fails instead.
class SensitiveClipboard {
  static const channel = MethodChannel('app.quantus/sensitive_clipboard');

  static const lifetime = Duration(minutes: 3);

  Timer? _clear;

  Future<void> copy(String text) async {
    if (defaultTargetPlatform == TargetPlatform.linux) {
      throw UnsupportedError('The app cannot keep a copy out of clipboard history on Linux yet.');
    }
    await channel.invokeMethod<void>('copy', {'text': text});
    _clear?.cancel();
    _clear = Timer(lifetime, () => unawaited(_clearCopy()));
  }

  Future<void> _clearCopy() async {
    _clear = null;
    try {
      await channel.invokeMethod<void>('clear');
    } catch (e) {
      // Nobody is waiting on the timer to hear this; quitting clears it too.
      quantusPrint('Clearing the copied secret from the clipboard failed: $e');
    }
  }

  void dispose() => _clear?.cancel();
}

final sensitiveClipboardProvider = Provider<SensitiveClipboard>((ref) {
  final clipboard = SensitiveClipboard();
  ref.onDispose(clipboard.dispose);
  return clipboard;
});
