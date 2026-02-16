import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/toaster.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

Future<void> showToaster(
  BuildContext context, {
  required String message,
  required IconData iconData,
  Color? iconColor,
  Duration duration = const Duration(seconds: 3),
  FlashBehavior behavior = FlashBehavior.floating,
}) async {
  if (!context.mounted) return;

  await context.showFlash<void>(
    duration: duration,
    persistent: false,
    builder: (context, controller) {
      return FlashBar(
        controller: controller,
        behavior: behavior,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        position: FlashPosition.top,
        clipBehavior: Clip.none,
        shouldIconPulse: false,
        content: Toaster(message: message, iconData: iconData, iconColor: iconColor),
      );
    },
  );
}

Future<void> showCopyToaster(BuildContext context, {required String message}) async {
  await showToaster(context, iconData: Icons.copy, message: message);
}

Future<void> showWarningToaster(BuildContext context, {required String message}) async {
  await showToaster(
    context,
    message: message,
    iconData: Icons.warning,
    iconColor: Colors.amber,
  );
}

Future<void> showInfoToaster(BuildContext context, {required String message}) async {
  await showToaster(context, message: message, iconData: Icons.info);
}

Future<void> showErrorToaster(BuildContext context, {required String message}) async {
  await showToaster(
    context,
    message: message,
    duration: const Duration(seconds: 10),
    iconData: Icons.error_rounded,
    iconColor: context.colors.error,
  );
}

Future<void> showSuccessToaster(BuildContext context, {required String message}) async {
  await showToaster(
    context,
    message: message,
    iconData: Icons.check_circle_rounded,
    iconColor: context.colors.success,
  );
}
