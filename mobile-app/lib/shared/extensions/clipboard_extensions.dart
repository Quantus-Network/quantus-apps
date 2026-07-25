import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/services/secure_clipboard_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

extension ClipboardWithToasterExtensions on BuildContext {
  Future<void> copyTextWithToaster(String text, {String message = 'Address copied to clipboard'}) async {
    await Clipboard.setData(ClipboardData(text: text));

    await showCopyToaster(message: message);
  }

  /// Copies sensitive [text] (e.g. a recovery phrase) to the clipboard and
  /// schedules it to be cleared automatically after [ttl] to limit exposure.
  Future<void> copySensitiveTextWithToaster(
    String text, {
    required String message,
    Duration ttl = SecureClipboardService.defaultTtl,
  }) async {
    await SecureClipboardService.instance.copyWithExpiry(text, ttl: ttl);

    await showCopyToaster(message: message);
  }
}
