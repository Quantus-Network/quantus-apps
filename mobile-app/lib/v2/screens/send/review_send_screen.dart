import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/url_utils.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_terminal_screen.dart';

class ReviewSendScreen extends ConsumerStatefulWidget {
  final SendStrategy strategy;
  final String recipientAddress;
  final BigInt amount;
  final SendFee fee;
  final String recipientChecksum;
  final bool isPayMode;

  const ReviewSendScreen({
    super.key,
    required this.strategy,
    required this.recipientAddress,
    required this.amount,
    required this.fee,
    required this.recipientChecksum,
    this.isPayMode = false,
  });

  @override
  ConsumerState<ReviewSendScreen> createState() => _ReviewSendScreenState();
}

class _ReviewSendScreenState extends ConsumerState<ReviewSendScreen> {
  bool _submitting = false;
  String? _errorMessage;
  Timer? _prefetchTimer;

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
    unawaited(
      widget.strategy
          .prefetchSignPayload(ref, recipientAddress: widget.recipientAddress.trim(), amount: widget.amount)
          .catchError((Object e) => quantusPrint('Keystone payload prefetch failed: $e')),
    );
  }

  Future<void> _toggleFlip() async {
    await ref.read(isCurrencyFlippedProvider.notifier).toggle();
  }

  Future<void> _confirmSend() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    SendOutcome outcome;
    try {
      outcome = await widget.strategy.submit(
        ref,
        recipientAddress: widget.recipientAddress.trim(),
        recipientChecksum: widget.recipientChecksum,
        amount: widget.amount,
        fee: widget.fee,
        isPayMode: widget.isPayMode,
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
      case SendNeedsHardwareSignature(:final session, :final terminal):
        setState(() => _submitting = false);
        final hash = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => KeystoneSignScreen(session: session)),
        );
        if (!mounted || hash == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                SendTerminalScreen(content: terminal.copyWith(explorerUrl: explorerImmediateTransactionUrl(hash))),
          ),
        );
      case SendNeedsProving(:final account, :final plan, :final amount, :final terminal):
        setState(() => _submitting = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EncryptedSendProgressScreen(
              account: account,
              plan: plan,
              amount: amount,
              recipientAddress: widget.recipientAddress.trim(),
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
    final colors = context.colors;
    final text = context.themeText;
    final approxDisplay = ref.watch(txAmountDisplayProvider)(
      widget.amount,
      isSend: true,
      withSignPrefix: false,
      withTokenSymbol: false,
      tokenDecimals: 4,
    );

    return ScaffoldBase(
      key: const Key(E2EKeys.sendReviewScreen),
      appBar: V2AppBar(title: widget.isPayMode ? l10n.sendPayTitle : strings.flowTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(colors, text, l10n, strings, approxDisplay),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: widget.strategy.reviewRows(
                  context,
                  ref,
                  recipientAddress: widget.recipientAddress,
                  amount: widget.amount,
                  fee: widget.fee,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: const Key(E2EKeys.sendConfirmButton),
          label: strings.reviewConfirmLabel,
          variant: ButtonVariant.primary,
          isLoading: _submitting,
          isDisabled: _submitting,
          onTap: _confirmSend,
        ),
      ),
    );
  }

  Widget _heroCard(
    AppColorsV2 colors,
    AppTextTheme text,
    AppLocalizations l10n,
    SendStrings strings,
    CurrencyDisplayState approxDisplay,
  ) {
    final sectionLabelStyle = text.receiveLabel?.copyWith(color: colors.textLabel);

    return SplitCard(
      topChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.reviewHeroLabel, style: sectionLabelStyle),
          const SizedBox(height: 16),
          AmountDisplayWithConversion(
            amountDisplay: approxDisplay,
            alignment: CrossAxisAlignment.start,
            onFlip: _toggleFlip,
          ),
        ],
      ),
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sendReviewTo, style: sectionLabelStyle),
          const SizedBox(height: 16),
          AddressCheckphraseWithInitial(
            recipientChecksum: widget.recipientChecksum,
            recipientAddress: widget.recipientAddress,
            showFullAddress: true,
          ),
        ],
      ),
    );
  }
}
