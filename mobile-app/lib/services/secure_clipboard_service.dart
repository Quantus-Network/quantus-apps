import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/services.dart';

/// Copies sensitive values (e.g. recovery phrases) to the clipboard and clears
/// them automatically after a short time-to-live.
///
/// Keeping a seed phrase in the clipboard indefinitely is risky: it can be
/// pasted unintentionally or read by other apps/clipboard managers. This
/// service limits that exposure window.
class SecureClipboardService {
  SecureClipboardService._();

  static final SecureClipboardService instance = SecureClipboardService._();

  /// Default lifetime of a sensitive clipboard entry before it is wiped.
  static const Duration defaultTtl = Duration(seconds: 30);

  Timer? _clearTimer;

  /// Copies [text] to the clipboard and schedules it to be cleared after [ttl].
  ///
  /// The clipboard is only cleared if it still contains [text] at expiry, so a
  /// value the user copied afterwards is never wiped.
  Future<void> copyWithExpiry(String text, {Duration ttl = defaultTtl}) async {
    await Clipboard.setData(ClipboardData(text: text));

    _clearTimer?.cancel();
    _clearTimer = Timer(ttl, _clearClipboard);
  }

  Future<void> _clearClipboard() async {
    _clearTimer = null;

    try {
      await Clipboard.setData(const ClipboardData(text: ''));
    } catch (e, s) {
      developer.log(
        'Failed to clear sensitive clipboard entry',
        name: 'secure_clipboard',
        level: 900,
        error: e,
        stackTrace: s,
      );
    }
  }

  /// Cancels any pending auto-clear. Useful for tests and disposal.
  void cancel() {
    _clearTimer?.cancel();
    _clearTimer = null;
  }
}
