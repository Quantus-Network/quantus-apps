import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

/// Small square copy button beside a value: copies [text] and confirms it
/// with [copiedMessage] in the toaster.
class CopyIconButton extends StatelessWidget {
  final String text;
  final String copiedMessage;

  const CopyIconButton({super.key, required this.text, required this.copiedMessage});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return GestureDetector(
      onTap: () => context.copyTextWithToaster(text, message: copiedMessage),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.xsBorder),
        child: Center(child: Icon(Icons.copy, color: colors.textContent, size: 12)),
      ),
    );
  }
}
