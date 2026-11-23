import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/swap/swap_confirmation.dart';
import 'package:wallet_core/swap/swap_review.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_summary.dart';

/// Shows a dry quote's terms. Confirming takes a live quote; when it
/// guarantees less or asks more than the one shown, the live terms replace
/// the shown ones and need a second confirmation. A swap out of QTC then sends the
/// deposit from [account]; in preflight the stand-in's deposit is made by hand
/// from the deposit screen, as the app cannot sign on its chain.
class ReviewSwapScreen extends ConsumerStatefulWidget {
  final Account account;
  final SwapQuote quote;

  const ReviewSwapScreen({super.key, required this.account, required this.quote});

  @override
  ConsumerState<ReviewSwapScreen> createState() => _ReviewSwapScreenState();
}

class _ReviewSwapScreenState extends ConsumerState<ReviewSwapScreen> {
  late SwapQuote _quote = widget.quote;
  late final _confirmation = SwapConfirmation(account: widget.account);
  bool _confirming = false;

  bool get _swapOut => _quote.fromToken.isQuantus;

  bool _sendsDeposit(SwapPreflight? preflight) => _swapOut && preflight == null;

  (Account, BigInt) get _feeKey => (widget.account, _quote.amountIn);

  /// Confirms the terms on screen, and says how it went: the swap's progress
  /// takes the review's place, live terms that are worse replace the ones
  /// shown, and what stopped it otherwise is said.
  Future<void> _confirm() async {
    final l10n = ref.read(l10nProvider);
    setState(() => _confirming = true);
    try {
      final outcome = await _confirmation.confirm(ref, _quote, isActive: () => mounted);
      if (!mounted) return;
      switch (outcome) {
        case SwapConfirmed(:final swap):
          Navigator.pushAndRemoveUntil(
            context,
            SwapProgressScreen.route(swap.id, account: widget.account),
            (route) => route.isFirst,
          );
        case SwapTooManyFollowed():
          context.showErrorToaster(message: l10n.swapTooManyFollowed(ActiveSwapsNotifier.maxFollowed));
        case SwapConfirmDropped():
          break;
        case SwapTermsChanged(:final quote):
          setState(() => _quote = quote);
          context.showWarningToaster(message: l10n.swapReviewPriceMoved);
        case SwapListingChanged():
          context.showErrorToaster(message: l10n.swapReviewListingChanged);
        case SwapNotAllowed():
          context.showErrorToaster(message: l10n.swapDisabledTitle);
        case SwapQuoteRefused(:final message):
          context.showErrorToaster(message: l10n.swapQuoteError(message));
        case SwapApprovalRequired():
          context.showErrorToaster(message: l10n.sendReviewAuthRequired);
        case SwapDepositFailed():
          context.showErrorToaster(message: l10n.sendReviewSubmitFailed);
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(swapServiceProvider, (_, _) => _confirmation.serviceRebuilt());
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final quote = _quote;
    final from = quote.fromToken;
    final sendsDeposit = _sendsDeposit(ref.watch(swapPreflightProvider));
    final fee = sendsDeposit ? ref.watch(swapDepositFeeProvider(_feeKey)) : null;
    final spendable = sendsDeposit ? ref.watch(effectiveBalanceProviderFamily(widget.account.accountId)).value : null;
    final available = ref.watch(remoteConfigProvider.select((c) => c.swapAvailable));
    final review = swapReviewOf(l10n, fmt, quote, available: available, fee: fee, spendable: spendable);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.swapReviewTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            SwapAmountsCard(quote: quote, payLabel: l10n.swapYouPay, receiveLabel: l10n.swapYouReceive),
            const SizedBox(height: 32),
            for (final row in review.rows)
              switch (row) {
                SwapRowText(:final label, :final value) => SwapDetailRow(label: label, value: value, monoLabel: true),
                SwapRowAddress(:final label, :final address) => SwapDetailRow(
                  label: label,
                  value: AddressFormattingService.formatAddress(address),
                  monoLabel: true,
                  monoValue: true,
                ),
              },
            if (review.unusedRefunded) ...[
              const SizedBox(height: 16),
              Text(l10n.swapReviewUnusedRefunded, style: text.caption.copyWith(color: colors.textMuted)),
            ],
            if (review.feeFailed) ...[
              const SizedBox(height: 16),
              SwapFeeFailedRow(onRetry: () => ref.invalidate(swapDepositFeeProvider(_feeKey))),
            ],
            if (review.insufficient) ...[
              const SizedBox(height: 16),
              Text(l10n.swapReviewInsufficient(from.symbol), style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
            if (!available) ...[
              const SizedBox(height: 16),
              Text(l10n.swapDisabledTitle, style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuantusButton.simple(
              label: _swapOut ? l10n.swapReviewConfirm : l10n.swapContinue,
              onTap: _confirm,
              isLoading: _confirming,
              isDisabled: review.blocked,
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
