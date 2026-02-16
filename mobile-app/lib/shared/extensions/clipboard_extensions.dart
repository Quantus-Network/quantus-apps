import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

extension ClipboardWithToasterExtensions on BuildContext {
  Future<void> copyTextWithToaster(String text, {String message = 'Address copied to clipboard'}) async {
    await Clipboard.setData(ClipboardData(text: text));

    await showCopyToaster(message: message);
  }
}
