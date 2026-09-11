import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

/// Placeholder rendered in place of an amount the screen has chosen to hide.
const String hiddenAmountText = '-----';

class AmountDisplayWithConversion extends StatelessWidget {
  final CurrencyDisplayState amountDisplay;
  final CrossAxisAlignment alignment;
  final bool colorizeAmount;
  final Color? amountColor;
  final bool useTokenLogo;
  final bool reserveSwitcherSpace;

  /// Masks the amount with [hiddenAmountText]. Owned by the screen that
  /// offers the hide toggle — never read from a global setting here.
  final bool isHidden;

  const AmountDisplayWithConversion({
    super.key,
    required this.amountDisplay,
    this.alignment = CrossAxisAlignment.center,
    this.colorizeAmount = false,
    this.amountColor,
    this.useTokenLogo = false,
    this.reserveSwitcherSpace = false,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    final primaryAmountColor = amountColor ?? (colorizeAmount ? colors.semanticSage : colors.textContent);
    const tokenLogoPrimarySize = 32.0;

    final tokenAmount = amountDisplay.isFlipped ? amountDisplay.secondaryAmount : amountDisplay.primaryAmount;
    final primaryAmount = isHidden ? hiddenAmountText : tokenAmount;

    final MainAxisAlignment mainAxisAlignment = switch (alignment) {
      CrossAxisAlignment.center => MainAxisAlignment.center,
      _ => MainAxisAlignment.start,
    };

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [
            if (useTokenLogo) ...[
              SvgPicture.asset(
                'assets/v2/uppercase_q.svg',
                width: tokenLogoPrimarySize,
                height: tokenLogoPrimarySize,
                colorFilter: ColorFilter.mode(colors.textContent, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: primaryAmount,
                    style: text.displayBalance.copyWith(color: primaryAmountColor),
                  ),
                  if (!useTokenLogo) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: AppConstants.tokenSymbol,
                      style: text.amountHero.copyWith(color: primaryAmountColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(height: reserveSwitcherSpace ? 28 : 17.5),
      ],
    );
  }
}
