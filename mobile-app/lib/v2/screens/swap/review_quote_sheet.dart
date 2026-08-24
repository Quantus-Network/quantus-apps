import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/deposit_screen.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

void showReviewQuoteSheet(BuildContext context, SwapQuote quote, String refundAddress) {
  BottomSheetContainer.show(
    context,
    builder: (_) => _ReviewQuoteContent(quote: quote, refundAddress: refundAddress),
  );
}

class _ReviewQuoteContent extends ConsumerWidget {
  final SwapQuote quote;
  final String refundAddress;
  const _ReviewQuoteContent({required this.quote, required this.refundAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final swapService = SwapService();
    final fromUsd = quote.fromAmount * swapService.getUsdPrice(quote.fromToken);
    final toUsd = quote.toAmount * swapService.getUsdPrice(quote.toToken);

    return BottomSheetContainer(
      title: l10n.swapReviewTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _swapVisual(context, colors, text, fromUsd, toUsd),
          const SizedBox(height: 48),
          _feeRow(
            l10n.swapReviewTotalFees,
            '${SwapService.formatTokenAmount(quote.networkFee, quote.fromToken)} ${quote.fromToken.symbol}',
            colors,
            text,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: MenuDivider()),
          _feeRow(
            l10n.swapReviewTotalAmount,
            '${SwapService.formatTokenAmount(quote.totalAmount, quote.fromToken)} ${quote.fromToken.symbol}',
            colors,
            text,
            highlight: true,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.swapReviewSlippageWarning(
              (quote.fromAmount * quote.slippageTolerance).toStringAsFixed(2),
              (quote.slippageTolerance * 100).toStringAsFixed(0),
            ),
            style: text.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          _confirmButton(context, l10n),
        ],
      ),
    );
  }

  Widget _swapVisual(BuildContext context, AppColorsV3 colors, AppTextThemeV3 text, double fromUsd, double toUsd) {
    final cardWidth = MediaQuery.of(context).size.width / 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _tokenCard(context, quote.fromToken, quote.fromAmount, fromUsd, cardWidth, colors, text),
        Icon(Icons.arrow_forward, color: colors.textMuted, size: 20),
        _tokenCard(context, quote.toToken, quote.toAmount, toUsd, cardWidth, colors, text),
      ],
    );
  }

  Widget _tokenCard(
    BuildContext context,
    SwapToken token,
    double amount,
    double usd,
    double width,
    AppColorsV3 colors,
    AppTextThemeV3 text,
  ) {
    return Container(
      width: width,
      height: 111,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: context.radiusV3.mdBorder),
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
                  Text(token.symbol, style: text.caption.copyWith(color: colors.textContent)),
                  Text(token.network, style: text.caption.copyWith(color: colors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(SwapService.formatTokenAmount(amount, token), style: text.amountRow.copyWith(color: colors.textContent)),
          Text('\$${usd.toStringAsFixed(2)}', style: text.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value, AppColorsV3 colors, AppTextThemeV3 text, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.caption.copyWith(color: colors.textMuted)),
        Text(value, style: text.body.copyWith(color: highlight ? colors.textContent : colors.textMuted)),
      ],
    );
  }

  Widget _confirmButton(BuildContext context, AppLocalizations l10n) {
    return QuantusButton.simple(
      label: l10n.swapReviewConfirm,
      variant: ButtonVariant.secondary,
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
