import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shared v3 centered dialog: title, plain-consequence body, primary CTA, Cancel.
///
/// Presentational only. Callers pass already-resolved [title], [body],
/// [actionLabel], and [cancelLabel] strings. Overlay presentation is
/// [showQuantusDialog].
class QuantusDialog extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final String cancelLabel;
  final bool isDestructive;
  final VoidCallback? onAction;
  final VoidCallback? onCancel;

  const QuantusDialog({
    super.key,
    required this.title,
    required this.body,
    required this.actionLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.onAction,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 326),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.lgBorder,
        border: Border.all(color: colors.borderEmphasis, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.headingRow.copyWith(color: colors.textContent)),
          const SizedBox(height: 10),
          Text(body, style: text.body.copyWith(color: colors.textMuted, height: 1.55)),
          const SizedBox(height: 18),
          QuantusButton.simple(
            label: actionLabel,
            variant: isDestructive ? ButtonVariant.danger : ButtonVariant.primary,
            onTap: onAction,
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(label: cancelLabel, variant: ButtonVariant.staged, onTap: onCancel),
        ],
      ),
    );
  }
}

/// Shows a centered [QuantusDialog].
///
/// Returns `true` when the primary action is tapped, `false` when Cancel is
/// tapped or the barrier is dismissed.
Future<bool> showQuantusDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  bool barrierDismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: QuantusDialog(
          title: title,
          body: body,
          actionLabel: actionLabel,
          cancelLabel: cancelLabel,
          isDestructive: isDestructive,
          onAction: () => Navigator.pop(dialogContext, true),
          onCancel: () => Navigator.pop(dialogContext, false),
        ),
      );
    },
  );
  return confirmed ?? false;
}
