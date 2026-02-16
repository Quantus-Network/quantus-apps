import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/toaster.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

Future<void> showToaster(
  BuildContext context, {
  required String message,
  Icon? icon,
  Duration duration = const Duration(seconds: 3),
  FlashBehavior style = FlashBehavior.floating,
}) async {
  if (!context.mounted) return;

  await context.showFlash<void>(
    duration: duration,
    persistent: true,
    builder: (context, controller) {
      return FlashBar(
        controller: controller,
        behavior: style,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        position: FlashPosition.top,
        clipBehavior: Clip.none,
        shouldIconPulse: false,
        content: Toaster(message: message, icon: icon),
      );
    },
  );
}

Future<void> showCopyToaster(BuildContext context, {required String message}) async {
  await showToaster(context, icon: const Icon(Icons.copy), message: message);
}

Future<void> showWarningToaster(BuildContext context, {required String message}) async {
  await showToaster(
    context,
    message: message,
    icon: const Icon(Icons.warning, color: Colors.amber),
  );
}

Future<void> showErrorToaster(BuildContext context, {required String message}) async {
  await showToaster(
    context,
    message: message,
    duration: const Duration(seconds: 10),
    icon: Icon(Icons.error_rounded, color: context.colors.error),
  );
}

Future<void> showSuccessToaster(BuildContext context, {required String message}) async {
  await showToaster(
    context,
    message: message,
    icon: Icon(Icons.check_circle_rounded, color: context.colors.success),
  );
}
