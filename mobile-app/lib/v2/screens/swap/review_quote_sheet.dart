import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/deposit_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

void showReviewQuoteSheet(BuildContext context, SwapQuote quote, String refundAddress) {
  BottomSheetContainer.show(
    context,
    builder: (_) => _ReviewQuoteContent(quote: quote, refundAddress: refundAddress),
  );
}

class _ReviewQuoteContent extends StatelessWidget {
  final SwapQuote quote;
  final String refundAddress;
  const _ReviewQuoteContent({required this.quote, required this.refundAddress});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final swapService = SwapService();
    final fromUsd = quote.fromAmount * swapService.getUsdPrice(quote.fromToken);
    final toUsd = quote.toAmount * swapService.getUsdPrice(quote.toToken);

    return BottomSheetContainer(
      title: 'Review Quote',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _swapVisual(context, colors, text, fromUsd, toUsd),
          const SizedBox(height: 48),
          _feeRow(
            'Total fees',
            '${SwapService.formatTokenAmount(quote.networkFee, quote.fromToken)} ${quote.fromToken.symbol}',
            colors,
            text,
          ),
          Divider(color: colors.separator, height: 32),
          _feeRow(
            'Total Amount',
            '${SwapService.formatTokenAmount(quote.totalAmount, quote.fromToken)} ${quote.fromToken.symbol}',
            colors,
            text,
            highlight: true,
          ),
          const SizedBox(height: 24),
          Text(
            'You could receive up to \$${(quote.fromAmount * quote.slippageTolerance).toStringAsFixed(2)} less based on the ${(quote.slippageTolerance * 100).toStringAsFixed(0)}% slippage you set',
            style: text.tiny?.copyWith(color: colors.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 24),
          _confirmButton(context, colors, text),
        ],
      ),
    );
  }

  Widget _swapVisual(BuildContext context, AppColorsV2 colors, AppTextTheme text, double fromUsd, double toUsd) {
    final cardWidth = MediaQuery.of(context).size.width / 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _tokenCard(quote.fromToken, quote.fromAmount, fromUsd, cardWidth, colors, text),
        Icon(Icons.arrow_forward, color: colors.textSecondary, size: 20),
        _tokenCard(quote.toToken, quote.toAmount, toUsd, cardWidth, colors, text),
      ],
    );
  }

  Widget _tokenCard(SwapToken token, double amount, double usd, double width, AppColorsV2 colors, AppTextTheme text) {
    return Container(
      width: width,
      height: 111,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TokenIcon(token: token, size: 22, networkBadgeSize: 9),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    token.symbol,
                    style: text.detail?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  Text(token.network, style: text.tiny?.copyWith(color: colors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            SwapService.formatTokenAmount(amount, token),
            style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 0),
          Text(
            '\$${usd.toStringAsFixed(2)}',
            style: text.detail?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, AppColorsV2 colors, AppTextTheme text, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.detail?.copyWith(color: colors.textSecondary)),
        Text(
          value,
          style: text.detail?.copyWith(
            color: highlight ? colors.textPrimary : colors.textSecondary,
            fontWeight: highlight ? FontWeight.w500 : null,
          ),
        ),
      ],
    );
  }

  Widget _confirmButton(BuildContext context, AppColorsV2 colors, AppTextTheme text) {
    return GlassButton.simple(
      label: 'Confirm',

      onTap: () async {
        final swapService = SwapService();
        final order = await swapService.createSwap(quote);
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => DepositScreen(order: order)));
      },
    );
  }
}
