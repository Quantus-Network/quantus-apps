import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/top_snackbar_content.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

// Helper function to show a custom top snackbar
Future<void> showTopSnackBar(
  BuildContext context, {
  required String title,
  required String message,
  Widget? icon,
  Duration duration = const Duration(seconds: 3), // Default duration
  FlashBehavior style = FlashBehavior.floating, // Floating style
}) async {
  if (!context.mounted) return;

  // Use context.showFlash<T> for better type safety and context awareness if
  // available, otherwise fallback to showFlash<T>
  await context.showFlash<void>(
    duration: duration,
    persistent: true,
    builder: (context, controller) {
      return FlashBar(
        controller: controller,
        behavior: style,
        backgroundColor: Colors.transparent, // FlashBar itself is transparent
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        position: FlashPosition.top, // Position at the top
        clipBehavior: Clip.none, // Allow shadow to be visible if added
        shouldIconPulse: false,
        // Pass the actual content widget
        content: TopSnackBarContent(
          title: title,
          message: message,
          icon: icon, // Pass the icon through
        ),
      );
    },
  );
}

Future<void> showCopySnackbar(BuildContext context, {required String title, required String message}) async {
  await showTopSnackBar(
    context,
    icon: Container(
      width: context.isTablet ? 44 : 36,
      height: context.isTablet ? 44 : 36,
      decoration: const ShapeDecoration(color: Color(0xFF494949), shape: OvalBorder()),
      alignment: Alignment.center,
      child: const CopyIcon(),
    ),
    title: title,
    message: message,
  );
}

Future<void> showWarningSnackbar(BuildContext context, {required String title, required String message}) async {
  await showTopSnackBar(
    context,
    title: title,
    message: message,
    icon: const Icon(Icons.warning, color: Colors.amber),
  );
}

Future<void> showErrorSnackbar(BuildContext context, {required String title, required String message}) async {
  await showTopSnackBar(
    context,
    title: title,
    message: message,
    duration: const Duration(seconds: 10),
    icon: Icon(Icons.error_rounded, color: context.themeColors.error),
  );
}

Future<void> showSuccessSnackbar(BuildContext context, {required String title, required String message}) async {
  await showTopSnackBar(
    context,
    title: title,
    message: message,
    icon: Icon(Icons.check_circle_rounded, color: context.themeColors.buttonSuccess),
  );
}
