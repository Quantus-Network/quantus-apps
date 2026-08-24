import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

/// Placeholder rendered in place of an amount the screen has chosen to hide.
const String hiddenAmountText = '-----';

class AmountDisplayWithConversion extends StatelessWidget {
  final CurrencyDisplayState amountDisplay;
  final VoidCallback? onFlip;
  final CrossAxisAlignment alignment;
  final bool colorizeAmount;
  final Color? amountColor;
  final bool useTokenLogo;

  /// Masks both amounts with [hiddenAmountText]. Owned by the screen that
  /// offers the hide toggle — never read from a global setting here.
  final bool isHidden;

  const AmountDisplayWithConversion({
    super.key,
    required this.amountDisplay,
    this.onFlip,
    this.alignment = CrossAxisAlignment.center,
    this.colorizeAmount = false,
    this.amountColor,
    this.useTokenLogo = false,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    final primaryAmountColor = amountColor ?? (colorizeAmount ? colors.semanticSage : colors.textContent);
    const tokenLogoPrimarySize = 32.0;

    final primaryAmount = isHidden ? hiddenAmountText : amountDisplay.primaryAmount;
    final secondaryAmount = isHidden ? hiddenAmountText : amountDisplay.secondaryAmount;

    final secondaryAmountColor = colors.textMuted;
    final secondaryAmountBaseStyle = text.body.copyWith(color: secondaryAmountColor);
    const tokenLogoSecondarySize = 12.0;

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
            if (useTokenLogo && !amountDisplay.isFlipped) ...[
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
                  if (!useTokenLogo && !amountDisplay.isFlipped) ...[
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
        Row(
          mainAxisAlignment: mainAxisAlignment,
          children: [
            if (useTokenLogo && amountDisplay.isFlipped) ...[
              Text('≈ ', style: secondaryAmountBaseStyle),
              SvgPicture.asset(
                'assets/v2/uppercase_q.svg',
                width: tokenLogoSecondarySize,
                height: tokenLogoSecondarySize,
                colorFilter: ColorFilter.mode(secondaryAmountColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 2),
              Text(secondaryAmount, style: secondaryAmountBaseStyle),
            ] else
              Text('≈ $secondaryAmount', style: secondaryAmountBaseStyle),
            if (onFlip != null) ...[
              const SizedBox(width: 8),
              QuantusIconButton.circular(
                icon: Icons.swap_vert,
                onTap: onFlip,
                isActive: amountDisplay.isFlipped,
                size: IconButtonSize.small,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
