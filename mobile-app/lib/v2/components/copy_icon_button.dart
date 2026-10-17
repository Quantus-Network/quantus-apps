import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

/// Small copy button beside a value: copies [text] and confirms it with
/// [copiedMessage] in the toaster. Square on a surface by default; [round]
/// makes it an outlined dot on the void.
class CopyIconButton extends StatelessWidget {
  final String text;
  final String copiedMessage;
  final double size;
  final bool round;

  const CopyIconButton({
    super.key,
    required this.text,
    required this.copiedMessage,
    this.size = 20,
    this.round = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return GestureDetector(
      onTap: () => context.copyTextWithToaster(text, message: copiedMessage),
      child: Container(
        width: size,
        height: size,
        decoration: round
            ? BoxDecoration(
                color: colors.bgVoid,
                shape: BoxShape.circle,
                border: Border.all(color: colors.borderHairline),
              )
            : BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.xsBorder),
        child: Center(child: Icon(Icons.copy, color: colors.textContent, size: 12)),
      ),
    );
  }
}
