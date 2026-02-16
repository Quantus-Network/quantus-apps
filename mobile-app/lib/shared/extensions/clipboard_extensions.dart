import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/v2/components/toaster_helper.dart';

extension ClipboardExtensions on Clipboard {
  static Future<void> copyTextWithSnackbar(
    BuildContext context,
    String text, {
    String title = 'Copied!',
    String message = 'Address copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    // ignore: use_build_context_synchronously
    await showCopySnackbar(context, title: title, message: message);
  }
}

extension ClipboardWithToasterExtensions on BuildContext {
  Future<void> copyTextWithToaster(
    String text, {
    String message = 'Address copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    await showCopyToaster(this, message: message);
  }
}