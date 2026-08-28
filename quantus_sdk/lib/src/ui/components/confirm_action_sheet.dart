import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Generic "are you sure?" confirmation sheet. Resolves to true when the user
/// taps the confirm action, false on cancel/dismiss.
Future<bool> showConfirmActionSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool isDestructive = false,
}) async {
  final confirmed = await BottomSheetContainer.show<bool>(
    context,
    builder: (_) => _ConfirmActionSheet(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return confirmed ?? false;
}

class _ConfirmActionSheet extends StatelessWidget {
  const _ConfirmActionSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final AppColorsV3 colors = context.colorsV3;
    final AppTextThemeV3 text = context.themeTextV3;

    return BottomSheetContainer(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, style: text.bodyLarge.copyWith(color: colors.textMuted)),
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: confirmLabel,
            variant: isDestructive ? ButtonVariant.danger : ButtonVariant.primary,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: cancelLabel,
            variant: ButtonVariant.staged,
            onTap: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
