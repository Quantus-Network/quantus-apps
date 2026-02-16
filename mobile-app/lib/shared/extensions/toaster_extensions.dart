import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/toaster_helper.dart' as th;

extension ToasterExtensions on BuildContext {
  Future<void> showSuccessToaster({required String message}) async {
    await th.showSuccessToaster(this, message: message);
  }

  Future<void> showWarningToaster({required String message}) async {
    await th.showWarningToaster(this, message: message);
  }

  Future<void> showErrorToaster({required String message}) async {
    await th.showErrorToaster(this, message: message);
  }

  Future<void> showCopyToaster({required String message}) async {
    await th.showCopyToaster(this, message: message);
  }

  Future<void> showInfoToaster({required String message}) async {
    await th.showInfoToaster(this, message: message);
  }
}
