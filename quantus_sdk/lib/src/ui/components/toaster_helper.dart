import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

Future<void> showToaster(
  BuildContext context, {
  required String message,
  required IconData iconData,
  required Color iconColor,
  required Color textColor,
  Duration duration = const Duration(seconds: 2),
}) async {
  if (!context.mounted) return;

  ToastController.instance.show(
    ToastRequest(message: message, iconData: iconData, iconColor: iconColor, textColor: textColor),
    duration,
  );
}

Future<void> showCopyToaster(BuildContext context, {required String message}) async {
  final colors = context.colorsV3;
  await showToaster(
    context,
    iconData: Icons.check,
    message: message,
    textColor: colors.semanticSage,
    iconColor: colors.semanticSage,
  );
}

Future<void> showWarningToaster(BuildContext context, {required String message}) async {
  final colors = context.colorsV3;
  await showToaster(
    context,
    message: message,
    iconData: Icons.warning,
    iconColor: colors.semanticSand,
    textColor: colors.textContent,
  );
}

Future<void> showInfoToaster(BuildContext context, {required String message}) async {
  final colors = context.colorsV3;
  await showToaster(
    context,
    message: message,
    iconData: Icons.info,
    iconColor: colors.textContent,
    textColor: colors.textContent,
  );
}

Future<void> showErrorToaster(BuildContext context, {required String message}) async {
  final colors = context.colorsV3;
  await showToaster(
    context,
    message: message,
    duration: const Duration(seconds: 10),
    iconData: Icons.error_rounded,
    iconColor: colors.semanticEmber,
    textColor: colors.textContent,
  );
}

Future<void> showSuccessToaster(BuildContext context, {required String message}) async {
  final colors = context.colorsV3;
  await showToaster(
    context,
    message: message,
    iconData: Icons.check_circle_rounded,
    iconColor: colors.semanticSage,
    textColor: colors.semanticSage,
  );
}
