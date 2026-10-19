import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';

/// Figma Cold Wallet dialog: the [QuantusDialog] layout with a coloured
/// title, an optional Cancel, buttons narrow enough for long labels and a
/// [ColdButton.danger] action when [isDestructive].
class ColdDialog extends StatelessWidget {
  final String title;

  /// Defaults to [AppColorsV3.textContent].
  final Color? titleColor;
  final String body;
  final String actionLabel;

  /// Null hides Cancel, leaving a single action such as "Done".
  final String? cancelLabel;
  final bool isDestructive;

  /// Sits between the title and the body.
  final Widget? banner;
  final VoidCallback? onAction;
  final VoidCallback? onCancel;

  const ColdDialog({
    super.key,
    required this.title,
    this.titleColor,
    required this.body,
    required this.actionLabel,
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.banner,
    this.onAction,
    this.onCancel,
  });

  static const _buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 16);

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final cancel = cancelLabel;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 326),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.lgBorder,
        border: Border.all(color: colors.borderEmphasis),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: text.titleScreen.copyWith(color: titleColor ?? colors.textContent)),
            const SizedBox(height: 10),
            ?banner,
            const SizedBox(height: 12),
            Text(body, style: text.body.copyWith(color: colors.textMuted, height: 1.55)),
            const SizedBox(height: 20),
            if (isDestructive)
              ColdButton.danger(label: actionLabel, onTap: onAction, padding: _buttonPadding)
            else
              QuantusButton.simple(label: actionLabel, onTap: onAction, padding: _buttonPadding),
            if (cancel != null) ...[
              const SizedBox(height: 10),
              QuantusButton.simple(
                label: cancel,
                variant: ButtonVariant.staged,
                onTap: onCancel,
                padding: _buttonPadding,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a centered [ColdDialog]. True when the action is tapped, false on
/// Cancel or a barrier tap.
Future<bool> showColdDialog(
  BuildContext context, {
  required String title,
  Color? titleColor,
  required String body,
  required String actionLabel,
  String? cancelLabel = 'Cancel',
  bool isDestructive = false,
  Widget? banner,
}) => showColdDialogWith(
  context,
  (action, cancel) => ColdDialog(
    title: title,
    titleColor: titleColor,
    body: body,
    actionLabel: actionLabel,
    cancelLabel: cancelLabel,
    isDestructive: isDestructive,
    banner: banner,
    onAction: action,
    onCancel: cancel,
  ),
);

/// Shows the dialog [build] returns centered; [action] closes it as true,
/// [cancel] and a barrier tap as false.
Future<bool> showColdDialogWith(
  BuildContext context,
  ColdDialog Function(VoidCallback action, VoidCallback cancel) build,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: build(() => Navigator.pop(dialogContext, true), () => Navigator.pop(dialogContext, false)),
    ),
  );
  return confirmed ?? false;
}

/// [dialog] over a dimmed backdrop, for the overlays beside the Navigator
/// (the lock and the offline gate) where a dialog route cannot be shown.
/// Fills the Stack it is placed in.
class InlineColdDialog extends StatelessWidget {
  final ColdDialog dialog;

  const InlineColdDialog({super.key, required this.dialog});

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: context.colorsV3.bgVoid.useOpacity(0.8),
        child: Center(
          child: Padding(padding: ScaffoldBase.defaultPadding, child: dialog),
        ),
      ),
    ),
  );
}
