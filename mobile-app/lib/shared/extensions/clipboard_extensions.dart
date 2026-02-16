import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/v2/components/toaster_helper.dart';

extension ClipboardWithToasterExtensions on BuildContext {
  Future<void> copyTextWithToaster(String text, {String message = 'Address copied to clipboard'}) async {
    await Clipboard.setData(ClipboardData(text: text));

    await showCopyToaster(this, message: message);
  }
}
