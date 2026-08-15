import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';

class AmountDisplayWithConversion extends StatelessWidget {
  final CurrencyDisplayState amountDisplay;
  final VoidCallback? onFlip;
  final CrossAxisAlignment alignment;
  final bool colorizeAmount;
  final Color? amountColor;
  final bool useTokenLogo;

  const AmountDisplayWithConversion({
    super.key,
    required this.amountDisplay,
    this.onFlip,
    this.alignment = CrossAxisAlignment.center,
    this.colorizeAmount = false,
    this.amountColor,
    this.useTokenLogo = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.themeText;
    final colors = context.colors;

    final primaryAmountColor = amountColor ?? (colorizeAmount ? colors.success : colors.textPrimary);
    final tokenLogoPrimarySize = 32.0;

    final secondaryAmountColor = colors.textTertiary;
    final secondaryAmountBaseStyle = text.paragraph?.copyWith(
      color: secondaryAmountColor,
      fontFamily: AppTextTheme.fontFamilySecondary,
    );
    final tokenLogoSecondarySize = 12.0;

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
                colorFilter: ColorFilter.mode(context.colors.textPrimary, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
            ],
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: amountDisplay.primaryAmount,
                    style: text.conversionAmountPrimary?.copyWith(color: primaryAmountColor),
                  ),
                  if (!useTokenLogo && !amountDisplay.isFlipped) ...[
                    const TextSpan(text: '     '),
                    TextSpan(
                      text: AppConstants.tokenSymbol,
                      style: text.mediumTitle?.copyWith(
                        fontFamily: AppTextTheme.fontFamilySecondary,
                        color: primaryAmountColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
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
              Text(amountDisplay.secondaryAmount, style: secondaryAmountBaseStyle),
            ] else
              Text('≈ ${amountDisplay.secondaryAmount}', style: secondaryAmountBaseStyle),
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
