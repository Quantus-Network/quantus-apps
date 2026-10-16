import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/outcome_view.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// Where every refused or rejected transaction ends (Figma Cold Wallet /
/// Rejected): what happened on this device, and what to do with the phone.
class RejectedScreen extends StatelessWidget {
  const RejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return OutcomeView(
      appBarTitle: 'Sign',
      glyph: ColdIcons.warningCircle,
      glyphColor: colors.semanticEmber,
      title: 'Nothing was signed',
      body: 'The transaction was discarded on this device. Your keys never left it and no funds moved.',
      bottom: QuantusButton.simple(
        label: 'Back to Home',
        padding: coldButtonPadding,
        onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
      children: [
        const _NumberedItem(
          number: '01',
          title: "Don't retry from the same phone",
          caption: "If it's compromised, retrying gives it another attempt.",
        ),
        Container(height: 1, color: colors.borderHairline),
        const _NumberedItem(
          number: '02',
          title: 'Your funds are safe here',
          caption: 'Move to a phone you trust before sending again.',
        ),
        const SizedBox(height: 32),
        const QuantusBanner(
          tone: BannerTone.ember,
          message: 'If your phone showed different details from this screen, treat that phone as compromised.',
        ),
      ],
    );
  }
}

class _NumberedItem extends StatelessWidget {
  final String number;
  final String title;
  final String caption;

  const _NumberedItem({required this.number, required this.title, required this.caption});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number, style: text.labelMonogram.copyWith(color: colors.semanticEmber)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
                const SizedBox(height: 4),
                Text(caption, style: text.caption.copyWith(color: colors.textMuted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
