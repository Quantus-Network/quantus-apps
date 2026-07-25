import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
    final AppColorsV2 colors = context.colors;
    final AppTextTheme text = context.themeText;

    return BottomSheetContainer(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(message, style: text.paragraph?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: confirmLabel,
            variant: isDestructive ? ButtonVariant.danger : ButtonVariant.primary,
            onTap: () => Navigator.pop(context, true),
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: cancelLabel,
            variant: ButtonVariant.secondary,
            onTap: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
