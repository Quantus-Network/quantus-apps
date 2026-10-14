import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// "Offline · ready to sign" status pill (Figma Cold Wallet / Toast): sage
/// gradient and border, wifi-slash glyph, one line of label.
class OfflinePill extends StatelessWidget {
  final String label;

  const OfflinePill({super.key, this.label = 'Offline · ready to sign'});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final sage = colors.semanticSage;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sage.useOpacity(0.16), sage.useOpacity(0.07)],
        ),
        border: Border.all(color: sage.useOpacity(0.3)),
        borderRadius: BorderRadius.circular(17),
        boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.45), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          ColdIcon(ColdIcons.wifiSlash, size: 14, color: sage),
          Text(label, style: context.themeTextV3.labelChip.copyWith(color: sage)),
        ],
      ),
    );
  }
}
