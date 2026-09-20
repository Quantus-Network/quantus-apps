import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/token_icon.dart';
import 'package:resonance_network_wallet/v2/screens/swap/deposit_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';

void showReviewQuoteSheet(BuildContext context, SwapQuote quote) {
  BottomSheetContainer.show(context, builder: (_) => _ReviewQuoteContent(quote: quote));
}

class _ReviewQuoteContent extends ConsumerStatefulWidget {
  final SwapQuote quote;
  const _ReviewQuoteContent({required this.quote});

  @override
  ConsumerState<_ReviewQuoteContent> createState() => _ReviewQuoteContentState();
}

class _ReviewQuoteContentState extends ConsumerState<_ReviewQuoteContent> {
  bool _confirming = false;

  SwapQuote get quote => widget.quote;

  Future<void> _confirm() async {
    final navigator = Navigator.of(context);
    setState(() => _confirming = true);
    try {
      final order = await ref.read(swapServiceProvider).createSwap(quote);
      if (!mounted) return;
      navigator.pop();
      navigator.push(MaterialPageRoute(builder: (_) => DepositScreen(order: order)));
    } catch (e) {
      quantusPrint('Swap create failed: $e');
      if (!mounted) return;
      context.showErrorToaster(message: ref.read(l10nProvider).swapQuoteError(describeSwapError(e)));
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  String _timeLabel(AppLocalizations l10n) {
    final seconds = quote.timeEstimate.inSeconds;
    return seconds < 60 ? l10n.swapReviewTimeSeconds(seconds) : l10n.swapReviewTimeMinutes((seconds / 60).ceil());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final to = quote.toToken;

    return BottomSheetContainer(
      title: l10n.swapReviewTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _swapVisual(context, fmt, colors, text),
          const SizedBox(height: 48),
          _row(
            l10n.swapReviewMinimumReceived,
            '${fmt.formatAmount(quote.minAmountOut, decimals: to.decimals)} ${to.symbol}',
            colors,
            text,
            highlight: true,
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: MenuDivider()),
          _row(l10n.swapReviewEstimatedTime, _timeLabel(l10n), colors, text),
          const SizedBox(height: 24),
          Text(
            l10n.swapReviewSlippageWarning(slippagePercentLabel(quote.slippageBps)),
            style: text.caption.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: l10n.swapReviewConfirm,
            variant: ButtonVariant.staged,
            onTap: _confirm,
            isLoading: _confirming,
          ),
        ],
      ),
    );
  }

  Widget _swapVisual(BuildContext context, NumberFormattingService fmt, AppColorsV3 colors, AppTextThemeV3 text) {
    final cardWidth = MediaQuery.of(context).size.width / 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _tokenCard(context, quote.fromToken, quote.amountIn, quote.amountInUsd, cardWidth, fmt, colors, text),
        Icon(Icons.arrow_forward, color: colors.textMuted, size: 20),
        _tokenCard(context, quote.toToken, quote.amountOut, quote.amountOutUsd, cardWidth, fmt, colors, text),
      ],
    );
  }

  Widget _tokenCard(
    BuildContext context,
    SwapToken token,
    BigInt amount,
    double usd,
    double width,
    NumberFormattingService fmt,
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
          Text(
            fmt.formatAmount(amount, decimals: token.decimals),
            style: text.amountRow.copyWith(color: colors.textContent),
            overflow: TextOverflow.ellipsis,
          ),
          Text('\$${usd.toStringAsFixed(2)}', style: text.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _row(String label, String value, AppColorsV3 colors, AppTextThemeV3 text, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: text.caption.copyWith(color: colors.textMuted)),
        Text(value, style: text.body.copyWith(color: highlight ? colors.textContent : colors.textMuted)),
      ],
    );
  }
}
