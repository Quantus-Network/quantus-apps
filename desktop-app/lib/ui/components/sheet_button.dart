import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The kinds of [SheetButton].
enum SheetButtonKind { primary, secondary, destructive }

/// A button at the foot of a sheet, at desktop size: 32 high, as wide as its
/// label. Buttons sit at the sheet's bottom right, the default one last.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = SheetButtonKind.primary,
    this.isDisabled = false,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onTap;
  final SheetButtonKind kind;
  final bool isDisabled;
  final bool isLoading;

  static const double height = 32;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final labelColor = isDisabled
        ? colors.textMuted2
        : switch (kind) {
            SheetButtonKind.primary => colors.textVoid,
            SheetButtonKind.secondary || SheetButtonKind.destructive => colors.textContent,
          };

    return SizedBox(
      height: height,
      child: QuantusButton.simple(
        label: label,
        onTap: onTap,
        isDisabled: isDisabled,
        isLoading: isLoading,
        variant: switch (kind) {
          SheetButtonKind.primary => ButtonVariant.primary,
          SheetButtonKind.secondary => ButtonVariant.staged,
          SheetButtonKind.destructive => ButtonVariant.danger,
        },
        // As wide as the label.
        width: null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        borderRadius: context.radiusV3.smBorder,
        textStyle: context.themeTextV3.bodyEmphasis.copyWith(height: 1, color: labelColor),
      ),
    );
  }
}
