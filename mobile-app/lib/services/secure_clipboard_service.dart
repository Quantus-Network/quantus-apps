import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Copies sensitive values (e.g. recovery phrases) to the clipboard and clears
/// them automatically after a short time-to-live.
///
/// Keeping a seed phrase in the clipboard indefinitely is risky: it can be
/// pasted unintentionally or read by other apps/clipboard managers. This
/// service limits that exposure window.
///
/// On iOS the expiry is enforced by the operating system via `UIPasteboard`'s
/// `expirationDate`, so the value is wiped at the deadline even while the app
/// is suspended or has been killed. On other platforms a Dart [Timer] is used,
/// which only runs while the app is in the foreground — if the app is
/// backgrounded before the TTL elapses, the clear happens when it next resumes.
class SecureClipboardService {
  SecureClipboardService._();

  static final SecureClipboardService instance = SecureClipboardService._();

  /// Channel to the native side for OS-enforced clipboard expiration.
  static const MethodChannel _channel = MethodChannel('app.quantus/secure_clipboard');

  /// Default lifetime of a sensitive clipboard entry before it is wiped.
  static const Duration defaultTtl = Duration(minutes: 3);

  Timer? _clearTimer;

  /// Copies [text] to the clipboard and arranges for it to be cleared after
  /// [ttl].
  ///
  /// Prefers OS-enforced expiration (iOS); falls back to an in-app [Timer]
  /// otherwise or if the platform call fails.
  Future<void> copyWithExpiry(String text, {Duration ttl = defaultTtl}) async {
    _clearTimer?.cancel();
    _clearTimer = null;

    if (Platform.isIOS && await _copyWithNativeExpiry(text, ttl)) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    _clearTimer = Timer(ttl, _clearClipboard);
  }

  /// Sets the clipboard natively with an OS-enforced expiration date.
  ///
  /// Returns `true` on success, `false` if the platform could not handle it, in
  /// which case the caller should fall back to the Dart timer.
  Future<bool> _copyWithNativeExpiry(String text, Duration ttl) async {
    try {
      final result = await _channel.invokeMethod<bool>('copyWithExpiry', {'text': text, 'ttlSeconds': ttl.inSeconds});
      return result ?? false;
    } catch (e, s) {
      developer.log(
        'Native clipboard expiry unavailable, falling back to timer',
        name: 'secure_clipboard',
        level: 900,
        error: e,
        stackTrace: s,
      );
      return false;
    }
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
