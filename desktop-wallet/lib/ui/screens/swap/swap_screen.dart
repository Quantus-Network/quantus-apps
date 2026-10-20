import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/balance_providers.dart';
import 'package:quantus_desktop_wallet/providers/controllers/cold_sign_flow.dart';
import 'package:quantus_desktop_wallet/providers/controllers/transaction_submission.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/settings_providers.dart';
import 'package:quantus_desktop_wallet/providers/swap_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/components/token_picker_dialog.dart';
import 'package:quantus_desktop_wallet/ui/screens/sign/sign_flow_dialog.dart';
import 'package:quantus_desktop_wallet/ui/screens/swap/swap_progress_view.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

String formatSwapAmount(NumberFormattingService fmt, BigInt value, SwapToken token, {bool exact = false}) =>
    '${exact ? fmt.formatExactAmount(value, decimals: token.decimals) : fmt.formatAmount(value, decimals: token.decimals)} ${token.symbol}';

String formatUsd(double value) => FiatCurrency.usd.format(value.toStringAsFixed(2));

/// QTC into another asset: quote, reserve a deposit address, sign the deposit
/// on the cold wallet, then follow the swap until it settles.
class SwapScreen extends ConsumerStatefulWidget {
  const SwapScreen({super.key});

  @override
  ConsumerState<SwapScreen> createState() => _SwapScreenState();
}

class _SwapScreenState extends ConsumerState<SwapScreen> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _recipient = TextEditingController();
  SwapToken? _to;
  bool _saveAddress = true;
  SwapQuote? _quote;
  bool _quoting = false;
  String? _quoteError;
  bool _confirming = false;
  SwapOrder? _order;
  String? _depositHash;
  BigInt? _depositFee;

  @override
  void initState() {
    super.initState();
    _amount.addListener(_invalidateQuote);
    _recipient.addListener(_invalidateQuote);
  }

  @override
  void dispose() {
    _amount.dispose();
    _recipient.dispose();
    super.dispose();
  }

  void _invalidateQuote() {
    if (_quote != null || _quoteError != null) {
      setState(() {
        _quote = null;
        _quoteError = null;
        _order = null;
      });
    } else {
      setState(() {});
    }
  }

  BigInt? get _amountIn => ref.read(numberFormattingServiceProvider).parseAmount(_amount.text.trim());

  SwapToken? get _quantus => ref.read(swapTokensProvider).value?.where((t) => t.isQuantus).firstOrNull;

  Future<void> _pickToken() async {
    final token = await showTokenPickerDialog(context);
    if (token == null) return;
    setState(() {
      _to = token;
      _quote = null;
      _quoteError = null;
      _order = null;
    });
  }

  Future<void> _getQuote() async {
    final account = ref.read(currentAccountProvider);
    final from = _quantus;
    final to = _to;
    final amount = _amountIn;
    final recipient = _recipient.text.trim();
    if (account == null || from == null || to == null || amount == null || amount <= BigInt.zero || recipient.isEmpty) {
      return;
    }
    setState(() {
      _quoting = true;
      _quoteError = null;
    });
    try {
      final quote = await ref
          .read(swapServiceProvider)
          .getQuote(
            from: from,
            to: to,
            amount: amount,
            refundAddress: account.accountId,
            recipient: recipient,
            slippageBps: ref.read(swapSlippageBpsProvider),
          );
      if (mounted) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) setState(() => _quoteError = describeSwapError(e));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  /// A live order at least as good as the quote on screen; a kept order is
  /// reused while its deadline leaves enough lead, so a retry keeps its
  /// deposit address. Null when the price moved, after updating the quote.
  Future<SwapOrder?> _liveOrder(SwapQuote quote, AppLocalizations l10n) async {
    final kept = _order;
    if (kept != null && kept.quote.deadline.isAfter(DateTime.now().add(SwapService.minimumDepositLead))) return kept;
    final order = await ref.read(swapServiceProvider).createSwap(quote);
    _order = order;
    final live = order.quote;
    if (live.minAmountOut >= quote.minAmountOut && live.amountIn <= quote.amountIn) return order;
    if (mounted) {
      setState(() => _quote = live);
      await context.showErrorToaster(message: l10n.swapPriceMoved);
    }
    return null;
  }

  Future<void> _confirm() async {
    final account = ref.read(currentAccountProvider);
    final quote = _quote;
    final to = _to;
    if (account == null || quote == null || to == null || _confirming) return;
    final l10n = ref.read(l10nProvider);
    final fee = ref.read(swapDepositFeeProvider((account, quote.amountIn))).value;
    if (fee == null) return;
    setState(() => _confirming = true);
    try {
      final SwapOrder? order;
      try {
        order = await _liveOrder(quote, l10n);
      } catch (e) {
        if (mounted) await context.showErrorToaster(message: l10n.swapCreateError(describeSwapError(e)));
        return;
      }
      if (order == null || !mounted) return;
      if (_saveAddress) {
        unawaited(
          ref
              .read(swapServiceProvider)
              .saveAddress(to.network, quote.recipient)
              .catchError((Object e) => debugPrint('Saving swap address failed: $e')),
        );
      }
      await _sign(account, order, fee, l10n);
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  Future<void> _sign(Account account, SwapOrder order, BigInt fee, AppLocalizations l10n) async {
    final formatter = ref.read(numberFormattingServiceProvider);
    final swap = ref.read(swapServiceProvider);
    final flow = ColdSignFlow(
      read: ref.read,
      account: account,
      buildCall: () =>
          ref.read(balancesServiceProvider).getBalanceTransferCall(order.depositAddress, order.quote.amountIn),
      key: ColdSignRequestKey.forExtrinsic(accountId: account.accountId, identity: 'swap|${order.quote.correlationId}'),
      bytesPerFrame: ref.read(qrDisplaySettingsProvider).bytesPerFrame,
      beforeBroadcast: () async => order.quote.deadline.isAfter(DateTime.now().add(const Duration(minutes: 1)))
          ? null
          : l10n.swapQuoteExpiredBeforeDeposit,
      onSubmitted: (hash, blockNumber) {
        trackSubmittedTransfer(
          ref,
          account: account,
          recipient: order.depositAddress,
          amount: order.quote.amountIn,
          fee: fee,
          extrinsicHash: hash,
          blockNumber: blockNumber,
        );
        unawaited(
          swap.submitDeposit(order, hash).catchError((Object e) => debugPrint('Swap deposit submit failed: $e')),
        );
      },
    );
    final hash = await showSignFlowDialog(
      context,
      flow: flow,
      details: ColdSignDetails(
        amount: l10n.commonQtcAmount(formatter.formatExactAmount(order.quote.amountIn)),
        recipient: order.depositAddress,
        recipientCheckphrase: ref.read(checksumNameProvider(order.depositAddress)).value,
      ),
    );
    flow.dispose();
    if (hash == null || !mounted) return;
    setState(() {
      _depositHash = hash;
      _depositFee = fee;
    });
  }

  void _reset() {
    _amount.clear();
    _recipient.clear();
    setState(() {
      _to = null;
      _quote = null;
      _quoteError = null;
      _order = null;
      _depositHash = null;
      _depositFee = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final order = _order;
    final depositHash = _depositHash;
    if (order != null && depositHash != null) {
      return DesktopPage(
        title: l10n.swapTitle,
        child: SwapProgressView(order: order, depositHash: depositHash, depositFee: _depositFee, onStartNew: _reset),
      );
    }
    final quote = _quote;
    return DesktopPage(
      title: l10n.swapTitle,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _form(l10n),
              if (quote != null) ...[const SizedBox(height: 24), _review(l10n, quote)],
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final tokens = ref.watch(swapTokensProvider);
    final from = tokens.value?.where((t) => t.isQuantus).firstOrNull;
    final to = _to;
    final amount = _amountIn;
    final slippage = ref.watch(swapSlippageBpsProvider);
    final spendable = ref.watch(spendableBalanceProvider).value;
    final saved = to == null ? null : ref.watch(swapSavedAddressesProvider(to.network)).value;
    final estimate = from != null && to != null && amount != null && amount > BigInt.zero
        ? swapEstimateOut(amount, from, to)
        : null;
    final ready =
        from != null && to != null && amount != null && amount > BigInt.zero && _recipient.text.trim().isNotEmpty;
    final label = text.labelMonogram.copyWith(color: colors.textMuted);

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.swapIntro, style: text.body.copyWith(color: colors.textMuted, height: 1.55)),
          if (tokens.hasError) ...[
            const SizedBox(height: 12),
            QuantusBanner(tone: BannerTone.ember, message: l10n.swapTokensError(describeSwapError(tokens.error!))),
          ] else if (tokens.hasValue && from == null) ...[
            const SizedBox(height: 12),
            QuantusBanner(tone: BannerTone.sand, message: l10n.swapNoQuantusListing),
          ],
          const SizedBox(height: 24),
          Text(l10n.swapPayLabel, style: label),
          const SizedBox(height: 8),
          QuantusTextField(
            controller: _amount,
            hint: l10n.sendAmountHint,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal)],
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                QuantusButton.simple(
                  label: l10n.sendMax,
                  variant: ButtonVariant.ghost,
                  width: null,
                  onTap: spendable == null ? null : () => _amount.text = formatter.formatExactAmount(spendable),
                ),
                Text(AppConstants.tokenSymbol, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
                const SizedBox(width: 12),
              ],
            ),
            trailingWidth: 130,
          ),
          if (estimate != null) ...[
            const SizedBox(height: 6),
            Text(
              l10n.swapEstimate(formatSwapAmount(formatter, estimate, to!)),
              style: text.caption.copyWith(color: colors.textMuted),
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.swapToLabel, style: label),
          const SizedBox(height: 8),
          Material(
            color: colors.bgSurface2,
            borderRadius: context.radiusV3.smBorder,
            child: InkWell(
              onTap: tokens.hasValue ? _pickToken : null,
              borderRadius: context.radiusV3.smBorder,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (to != null) ...[TokenLogo(token: to, size: 28), const SizedBox(width: 12)],
                    Expanded(
                      child: to == null
                          ? Text(l10n.swapPickToken, style: text.body.copyWith(color: colors.textMuted))
                          : Text(
                              '${to.symbol} · ${to.networkName}',
                              style: text.bodyEmphasis.copyWith(color: colors.textContent),
                            ),
                    ),
                    Icon(Icons.unfold_more_rounded, size: 18, color: colors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          if (to != null) ...[
            const SizedBox(height: 24),
            Text(l10n.swapRecipientLabel(to.networkName.toUpperCase()), style: label),
            const SizedBox(height: 8),
            QuantusTextField(
              controller: _recipient,
              hint: l10n.swapRecipientHint(to.networkName),
              showClearButton: true,
              trailing: saved == null || saved.isEmpty
                  ? null
                  : MenuAnchor(
                      menuChildren: [
                        for (final address in saved)
                          MenuItemButton(
                            onPressed: () => _recipient.text = address,
                            child: Text(address, style: text.dataAddress.copyWith(color: colors.textContent)),
                          ),
                      ],
                      builder: (context, controller, _) => QuantusIconButton.ghost(
                        icon: Icons.history_rounded,
                        size: IconButtonSize.small,
                        onTap: () => controller.isOpen ? controller.close() : controller.open(),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(l10n.swapRecipientNotice(to.symbol), style: text.caption.copyWith(color: colors.textMuted)),
            Row(
              children: [
                Checkbox(
                  value: _saveAddress,
                  activeColor: colors.accentFlare,
                  onChanged: (v) => setState(() => _saveAddress = v ?? true),
                ),
                Text(l10n.swapSaveAddress, style: text.caption.copyWith(color: colors.textMuted)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(l10n.swapSlippage, style: label),
          const SizedBox(height: 4),
          Text(l10n.swapSlippageBody, style: text.caption.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            width: 320,
            child: SegmentedControls<int>(
              items: [
                for (final bps in swapSlippageOptionsBps)
                  SegmentedControlItem(value: bps, label: l10n.swapSlippagePercent(slippagePercentLabel(bps))),
              ],
              selectedValue: swapSlippageOptionsBps.contains(slippage) ? slippage : swapSlippageOptionsBps[1],
              onChanged: (bps) {
                ref.read(swapSlippageBpsProvider.notifier).state = bps;
                _invalidateQuote();
              },
            ),
          ),
          if (_quoteError != null) ...[
            const SizedBox(height: 16),
            QuantusBanner(tone: BannerTone.ember, message: l10n.swapQuoteError(_quoteError!)),
          ],
          const SizedBox(height: 24),
          QuantusButton.simple(label: l10n.swapGetQuote, isDisabled: !ready, isLoading: _quoting, onTap: _getQuote),
        ],
      ),
    );
  }

  Widget _review(AppLocalizations l10n, SwapQuote quote) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final account = ref.watch(currentAccountProvider)!;
    final fee = ref.watch(swapDepositFeeProvider((account, quote.amountIn)));
    final spendable = ref.watch(spendableBalanceProvider).value;
    final feeValue = fee.value;
    final insufficient = feeValue != null && spendable != null && quote.amountIn + feeValue > spendable;
    final from = quote.fromToken;
    final to = quote.toToken;
    final allowance = quote.amountOut - quote.minAmountOut;
    return DesktopCard(
      title: l10n.swapReviewTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwapAmountsCard(quote: quote, payLabel: l10n.swapPayLabel, receiveLabel: l10n.swapReceiveLabel),
          const SizedBox(height: 16),
          QuantusDataRow(
            label: l10n.swapRate,
            value: l10n.swapRateValue(
              from.symbol,
              formatter.formatAmount(swapQuoteRate(quote), decimals: to.decimals),
              to.symbol,
            ),
          ),
          QuantusDataRow(label: l10n.swapRecipient, value: AddressFormattingService.formatAddress(quote.recipient)),
          QuantusDataRow(
            label: l10n.swapRefundAddress,
            value: AddressFormattingService.formatAddress(quote.refundAddress),
          ),
          QuantusDataRow(
            label: l10n.swapNetworkFee,
            value: fee.hasError
                ? l10n.swapFeeUnavailable
                : feeValue == null
                ? '…'
                : formatSwapAmount(formatter, feeValue, from, exact: true),
          ),
          QuantusDataRow(
            label: l10n.swapSlippageAllowance,
            value: l10n.swapSlippageAllowanceValue(
              formatSwapAmount(formatter, allowance, to),
              slippagePercentLabel(quote.slippageBps),
            ),
          ),
          QuantusDataRow(label: l10n.swapGuaranteedMinimum, value: formatSwapAmount(formatter, quote.minAmountOut, to)),
          const SizedBox(height: 8),
          Text(l10n.swapUnusedRefunded, style: text.caption.copyWith(color: colors.textMuted)),
          if (insufficient) ...[
            const SizedBox(height: 12),
            QuantusBanner(tone: BannerTone.ember, message: l10n.swapInsufficient),
          ],
          const SizedBox(height: 20),
          QuantusButton.simple(
            label: l10n.swapConfirm,
            isDisabled: feeValue == null || insufficient,
            isLoading: _confirming,
            onTap: _confirm,
          ),
        ],
      ),
    );
  }
}

/// What goes in and what comes out, with their USD values at listed prices.
class SwapAmountsCard extends ConsumerWidget {
  final SwapQuote quote;
  final String payLabel;
  final String receiveLabel;

  const SwapAmountsCard({super.key, required this.quote, required this.payLabel, required this.receiveLabel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    Widget side(String label, BigInt amount, SwapToken token, double usd) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelMonogram.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          Row(
            children: [
              TokenLogo(token: token, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatSwapAmount(formatter, amount, token, exact: true),
                  style: text.amountRow.copyWith(color: colors.textContent),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(formatUsd(usd), style: text.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: context.radiusV3.smBorder),
      child: Row(
        children: [
          side(payLabel, quote.amountIn, quote.fromToken, quote.amountInUsd),
          Icon(Icons.arrow_forward_rounded, size: 18, color: colors.textMuted),
          const SizedBox(width: 16),
          side(receiveLabel, quote.amountOut, quote.toToken, quote.amountOutUsd),
        ],
      ),
    );
  }
}
