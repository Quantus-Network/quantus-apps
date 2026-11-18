import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/link_button.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';
import 'package:wallet_core/send/send_review.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_screen_logic.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_terminal_screen.dart';

class ReviewSendScreen extends ConsumerStatefulWidget {
  final SendStrategy strategy;
  final String recipientAddress;
  final BigInt amount;
  final SendFee fee;
  final bool isPayMode;

  /// Max send: the amount is whatever the settled fee leaves of the spendable
  /// balance, and confirmation waits for that fee.
  final bool sendAll;

  const ReviewSendScreen({
    super.key,
    required this.strategy,
    required this.recipientAddress,
    required this.amount,
    required this.fee,
    this.isPayMode = false,
    this.sendAll = false,
  });

  @override
  ConsumerState<ReviewSendScreen> createState() => _ReviewSendScreenState();
}

class _ReviewSendScreenState extends ConsumerState<ReviewSendScreen> {
  bool _submitting = false;
  String? _errorMessage;
  Timer? _prefetchTimer;

  String get _recipient => widget.recipientAddress.trim();

  ProviderListenable<SendFeeState> get _feeProvider =>
      widget.strategy.feeProvider(recipient: _recipient, amount: widget.amount);

  SendFeeState get _feeState => ref.read(_feeProvider);

  BigInt? get _spendable => ref.read(widget.strategy.spendableBalanceProvider).value;

  /// The send as the fee and the balance leave it now.
  SendReview get _review => SendReview.of(
    widget.strategy,
    feeState: _feeState,
    openedWith: widget.fee,
    spendable: _spendable,
    enteredAmount: widget.amount,
    sendAll: widget.sendAll,
  );

  @override
  void initState() {
    super.initState();
    // Warm hardware-signing payloads while the user reviews, and keep them
    // warm: a cache hit is a no-op, so the periodic tick only refetches once
    // the mortal-era window has expired the cached entry.
    _prefetchSignPayload();
    _prefetchTimer = Timer.periodic(const Duration(seconds: 30), (_) => _prefetchSignPayload());
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    super.dispose();
  }

  void _prefetchSignPayload() {
    final review = _review;
    unawaited(
      widget.strategy
          .prefetchSignPayload(
            ref,
            recipientAddress: _recipient,
            amount: review.amount,
            fee: review.fee,
            sendAll: widget.sendAll,
          )
          .catchError((Object e) => quantusPrint('Keystone payload prefetch failed: $e')),
    );
  }

  Future<void> _confirmSend() async {
    final review = _review;
    if (review.confirmBlocked) {
      quantusPrint('Confirm ignored: the fee no longer allows this send');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    SendOutcome outcome;
    try {
      outcome = await widget.strategy.submit(
        ref,
        recipientAddress: _recipient,
        amount: review.amount,
        fee: review.fee,
        isPayMode: widget.isPayMode,
        sendAll: widget.sendAll,
      );
    } catch (e, st) {
      quantusPrint('Send submit error: $e\n$st');
      if (!mounted) return;
      outcome = SendFailed(ref.read(l10nProvider).sendReviewSubmitFailed);
    }
    if (!mounted) return;

    switch (outcome) {
      case SendSubmitted(:final terminal):
        setState(() {
          _submitting = false;
          _errorMessage = null;
        });
        Navigator.push(context, MaterialPageRoute(builder: (_) => SendTerminalScreen(content: terminal)));
      case SendNeedsHardwareSignature(:final session, :final terminalForHash):
        setState(() => _submitting = false);
        final hash = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => KeystoneSignScreen(session: session)),
        );
        if (!mounted || hash == null) return;
        Navigator.push(context, MaterialPageRoute(builder: (_) => SendTerminalScreen(content: terminalForHash(hash))));
      case SendNeedsProving(:final account, :final plan, :final amount, :final terminal):
        setState(() => _submitting = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EncryptedSendProgressScreen(
              account: account,
              plan: plan,
              amount: amount,
              recipientAddress: _recipient,
              terminal: terminal,
            ),
          ),
        );
      case SendFailed(:final message):
        setState(() {
          _submitting = false;
          _errorMessage = message;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final strings = widget.strategy.strings(l10n);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    // Watched for rebuilds; the getters above read the same providers.
    ref.watch(_feeProvider);
    ref.watch(widget.strategy.spendableBalanceProvider);
    final review = _review;
    final fee = review.fee;
    final amount = review.amount;
    final feeApplies = review.feeApplies;
    final amountStatus = review.amountStatus;
    final feeFailed = review.feeFailed;
    final message = amountStatus != AmountStatus.valid
        ? SendScreenLogic.getButtonText(
            l10n: l10n,
            hasAddressError: false,
            amountStatus: amountStatus,
            recipientText: _recipient,
            amount: amount,
            activeAccountId: widget.strategy.sourceAccountId ?? '',
            formattingService: ref.watch(numberFormattingServiceProvider),
          )
        : feeFailed
        ? strings.feeFetchFailedMessage
        : _errorMessage;
    var approxDisplay = ref.watch(txAmountDisplayProvider)(
      amount,
      isSend: true,
      withSignPrefix: false,
      withTokenSymbol: false,
      tokenDecimals: 4,
    );
    if (widget.sendAll && !feeApplies) {
      approxDisplay = approxDisplay.copyWith(primaryAmount: estimateLabel(approxDisplay.primaryAmount, estimate: true));
    }

    return ScaffoldBase(
      key: const Key(E2EKeys.sendReviewScreen),
      appBar: V2AppBar(title: widget.isPayMode ? l10n.sendPayTitle : strings.flowTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(l10n, strings, approxDisplay),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _summaryRows(
                  widget.strategy.reviewRows(
                    ref,
                    recipientAddress: widget.recipientAddress,
                    amount: amount,
                    fee: fee,
                    feeIsEstimate: !feeApplies,
                    sendAll: widget.sendAll,
                  ),
                ),
              ),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: text.caption.copyWith(color: colors.semanticEmber)),
          ],
          if (feeFailed) ...[
            const SizedBox(height: 4),
            LinkButton(
              label: l10n.homeActivityRetry,
              onTap: () => widget.strategy.retryFee(ref, recipient: _recipient, amount: widget.amount),
            ),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.sendConfirmButton),
          label: strings.reviewConfirmLabel,
          variant: ButtonVariant.primary,
          isLoading: _submitting,
          isDisabled: _submitting || review.confirmBlocked,
          onTap: _confirmSend,
        ),
      ),
    );
  }

  /// The strategy's summary rows as this screen draws them, with a gap above,
  /// between and below: seven high, or four once there are more than four
  /// rows, as a multisig proposal has.
  List<Widget> _summaryRows(List<SendReviewRow> rows) {
    final gap = SizedBox(height: rows.length > 4 ? 4.0 : 7.0);
    return [
      gap,
      for (final row in rows) ...[
        switch (row) {
          SendReviewText(:final label, :final value) => DetailSummaryRow.review(label: label, value: value),
          SendReviewThreshold(:final label, :final text) => DetailSummaryRow.review(label: label, value: text),
          SendReviewAddress(:final label, :final address) => DetailSummaryRow.review(
            label: label,
            value: address,
            checkphraseAddress: address,
            valueFlex: 4,
          ),
          SendReviewExpiry(:final label, :final expiry) => DetailSummaryRow.review(
            label: label,
            valueWidget: MultisigExpiryValue(parts: expiry),
            valueFlex: 4,
          ),
        },
        gap,
      ],
    ];
  }

  Widget _heroCard(AppLocalizations l10n, SendStrings strings, CurrencyDisplayState approxDisplay) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final sectionLabelStyle = text.labelData.copyWith(color: colors.textMuted);

    return SplitCard(
      topChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.reviewHeroLabel, style: sectionLabelStyle),
          const SizedBox(height: 16),
          AmountDisplayWithConversion(amountDisplay: approxDisplay, alignment: CrossAxisAlignment.start),
        ],
      ),
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sendReviewTo, style: sectionLabelStyle),
          const SizedBox(height: 16),
          AddressCheckphraseWithInitial(address: widget.recipientAddress, showFullAddress: true),
        ],
      ),
    );
  }
}
