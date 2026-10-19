import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/outcome_view.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// Key Created (Figma 798:6225). The wallet already exists, so there is no
/// way back; "Go To Wallet" unwinds to the root, which is Home now.
class KeyCreatedScreen extends StatelessWidget {
  final ColdAccount account;

  const KeyCreatedScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return PopScope(
      canPop: false,
      child: OutcomeView(
        appBarTitle: 'New Key',
        showBackButton: false,
        glyph: ColdIcons.checkCircle,
        glyphColor: colors.semanticSage,
        title: 'Key Created',
        body: 'One account was created on this device.',
        bottom: QuantusButton.simple(
          label: 'Go To Wallet',
          padding: coldButtonPadding,
          onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.bgSurface,
              borderRadius: context.radiusV3.mdBorder,
              border: Border.all(color: colors.borderHairline),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: context.radiusV3.smBorder),
                  child: Center(child: ColdIcon(ColdIcons.key, size: 24, color: colors.accentFlare)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.label, style: text.headingRow.copyWith(color: colors.textContent)),
                      const SizedBox(height: 4),
                      Text('Signs for your main account.', style: text.caption.copyWith(color: colors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
