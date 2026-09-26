import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/link_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_summary.dart';

/// Shows a dry quote's terms. Confirming takes a live quote; when its
/// guaranteed minimum is below the one shown, the live terms replace the shown
/// ones and need a second confirmation. A swap out of QTC then sends the
/// deposit from [account].
class ReviewSwapScreen extends ConsumerStatefulWidget {
  final Account account;
  final SwapQuote quote;

  const ReviewSwapScreen({super.key, required this.account, required this.quote});

  @override
  ConsumerState<ReviewSwapScreen> createState() => _ReviewSwapScreenState();
}

class _ReviewSwapScreenState extends ConsumerState<ReviewSwapScreen> {
  late SwapQuote _quote = widget.quote;
  SwapOrder? _order;
  bool _confirming = false;

  bool get _swapOut => _quote.fromToken.isQuantus;

  (Account, BigInt) get _feeKey => (widget.account, _quote.amountIn);

  Future<void> _confirm() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _confirming = true);
    try {
      final order = await _liveOrder(l10n);
      if (order == null || !mounted) return;
      final fee = _swapOut ? ref.read(swapDepositFeeProvider(_feeKey)).requireValue : null;
      final txHash = fee != null ? await _sendDeposit(order, fee, l10n) : null;
      if ((fee != null && txHash == null) || !mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              SwapProgressScreen(account: widget.account, order: order, depositTxHash: txHash, depositFee: fee),
        ),
        (route) => route.isFirst,
      );
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  /// A live order at least as good as the terms on screen, or null when the
  /// terms on screen changed. A live order is kept until close to its deadline,
  /// so a retry reuses its deposit address.
  Future<SwapOrder?> _liveOrder(AppLocalizations l10n) async {
    final kept = _order;
    if (kept != null && kept.quote.deadline.isAfter(DateTime.now().add(SwapService.minimumDepositLead))) return kept;
    try {
      final order = await ref.read(swapServiceProvider).createSwap(_quote);
      _order = order;
      if (order.quote.minAmountOut >= _quote.minAmountOut) return order;
      if (mounted) {
        setState(() => _quote = order.quote);
        context.showWarningToaster(message: l10n.swapReviewPriceMoved);
      }
    } catch (e) {
      quantusPrint('Swap create failed: $e');
      if (mounted) context.showErrorToaster(message: l10n.swapQuoteError(describeSwapError(e)));
    }
    return null;
  }

  /// Sends the quoted QTC into the deposit address; null when nothing was sent.
  Future<String?> _sendDeposit(SwapOrder order, BigInt fee, AppLocalizations l10n) async {
    try {
      final hash = await RegularSendStrategy(
        account: widget.account,
      ).submitLocal(ref, recipient: order.depositAddress, amount: order.quote.amountIn, networkFee: fee);
      if (hash == null) {
        if (mounted) context.showErrorToaster(message: l10n.sendReviewAuthRequired);
        return null;
      }
      unawaited(
        ref
            .read(swapServiceProvider)
            .submitDeposit(order, hash)
            .catchError((Object e) => quantusPrint('Swap deposit submit failed: $e')),
      );
      return hash;
    } catch (e) {
      quantusPrint('Swap deposit transfer failed: $e');
      if (mounted) context.showErrorToaster(message: l10n.sendReviewSubmitFailed);
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final quote = _quote;
    final from = quote.fromToken;
    final to = quote.toToken;
    String amount(BigInt value, SwapToken token) => formatSwapAmount(l10n, fmt, value, token);
    Widget row(String label, String value, {bool mono = false}) =>
        SwapDetailRow(label: label, value: value, monoLabel: true, monoValue: mono);

    final fee = _swapOut ? ref.watch(swapDepositFeeProvider(_feeKey)) : null;
    final spendable = _swapOut ? ref.watch(effectiveMaxBalanceProviderFamily(widget.account.accountId)).value : null;
    final feeValue = fee?.value;
    final insufficient = feeValue != null && spendable != null && quote.amountIn + feeValue > spendable;
    final blocked = _swapOut && (feeValue == null || spendable == null || insufficient);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.swapReviewTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            SwapAmountsCard(quote: quote, payLabel: l10n.swapYouPay, receiveLabel: l10n.swapYouReceive),
            const SizedBox(height: 32),
            row(
              l10n.swapRate,
              l10n.swapRateLabel(from.symbol, fmt.formatAmount(swapQuoteRate(quote), decimals: to.decimals), to.symbol),
            ),
            if (_swapOut)
              row(l10n.swapReviewRecipient, AddressFormattingService.formatAddress(quote.recipient), mono: true)
            else
              row(
                l10n.swapReviewRefundAddress,
                AddressFormattingService.formatAddress(quote.refundAddress),
                mono: true,
              ),
            if (fee != null)
              row(
                l10n.swapReviewNetworkFee,
                fee.hasError ? l10n.swapReviewFeeUnavailable : (feeValue == null ? '…' : amount(feeValue, from)),
              ),
            row(
              l10n.swapReviewSlippage,
              l10n.swapReviewSlippageValue(
                amount(quote.amountOut - quote.minAmountOut, to),
                slippagePercentLabel(quote.slippageBps),
              ),
            ),
            row(l10n.swapReviewGuaranteedMinimum, amount(quote.minAmountOut, to)),
            if (fee != null && fee.hasError) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.swapReviewFeeFailed, style: text.caption.copyWith(color: colors.semanticEmber)),
                  ),
                  LinkButton(label: l10n.commonRetry, onTap: () => ref.invalidate(swapDepositFeeProvider(_feeKey))),
                ],
              ),
            ],
            if (insufficient) ...[
              const SizedBox(height: 16),
              Text(l10n.swapReviewInsufficient(from.symbol), style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuantusButton.simple(
              label: l10n.swapReviewConfirm,
              onTap: _confirm,
              isLoading: _confirming,
              isDisabled: blocked,
            ),
            const SizedBox(height: 4),
            QuantusButton.simple(
              label: l10n.commonCancel,
              variant: ButtonVariant.underline,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
