import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_miner/src/ui/snackbar_helper.dart' as sh;

extension SnackbarExtensions on BuildContext {
  Future<void> copyTextWithSnackbar(
    String text, {
    String title = 'Copied!',
    String message = 'Address copied to clipboard',
  }) async {
    await Clipboard.setData(ClipboardData(text: text));

    await sh.showCopySnackbar(this, title: title, message: message);
  }

  Future<void> showWarningSnackbar({required String title, required String message}) async {
    await sh.showWarningSnackbar(this, title: title, message: message);
  }

  Future<void> showErrorSnackbar({required String title, required String message}) async {
    await sh.showErrorSnackbar(this, title: title, message: message);
  }
}
