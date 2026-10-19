import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/outcome_view.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

const _dontRetry = (
  title: "Don't retry from the same phone",
  caption: "If it's compromised, retrying gives it another attempt.",
);

/// Where every refused or rejected transaction ends (Figma Cold Wallet /
/// Rejected): what happened on this device, and what to do with the phone.
/// With [signatureShown] the device had already signed and shown the
/// signature when the user rejected, which it cannot take back.
class RejectedScreen extends StatelessWidget {
  final bool signatureShown;

  const RejectedScreen({super.key, this.signatureShown = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final items = signatureShown
        ? const [
            (
              title: "Check the phone's wallet",
              caption: 'If the transaction was sent, it shows in the activity there.',
            ),
            _dontRetry,
          ]
        : const [
            _dontRetry,
            (title: 'Your funds are safe here', caption: 'Move to a phone you trust before sending again.'),
          ];
    return OutcomeView(
      appBarTitle: 'Sign',
      glyph: ColdIcons.warningCircle,
      glyphColor: colors.semanticEmber,
      title: signatureShown ? 'The signature was shown' : 'Nothing was signed',
      body: signatureShown
          ? 'This device signed the transaction and showed the signature before you rejected it. If your phone '
                'scanned the code, it can still send the transaction. A signature cannot be taken back.'
          : 'The transaction was discarded on this device. Your keys never left it and no funds moved.',
      bottom: QuantusButton.simple(
        label: 'Back to Home',
        padding: coldButtonPadding,
        onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
      ),
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0) Container(height: 1, color: colors.borderHairline),
          _NumberedItem(number: '0${i + 1}', title: item.title, caption: item.caption),
        ],
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
