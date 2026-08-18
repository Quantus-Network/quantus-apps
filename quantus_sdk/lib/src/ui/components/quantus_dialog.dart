import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Shared v3 centered dialog: title, plain-consequence body, primary CTA.
///
/// Presentational only. Callers pass already-resolved [title], [body], and
/// [actionLabel] strings. Overlay presentation is [showQuantusDialog].
class QuantusDialog extends StatelessWidget {
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onAction;

  const QuantusDialog({super.key, required this.title, required this.body, required this.actionLabel, this.onAction});

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
          QuantusButton.simple(label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

/// Shows a centered [QuantusDialog].
///
/// Returns `true` when the primary action is tapped, `false` if the barrier is dismissed.
Future<bool> showQuantusDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
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
          onAction: () => Navigator.pop(dialogContext, true),
        ),
      );
    },
  );
  return confirmed ?? false;
}
