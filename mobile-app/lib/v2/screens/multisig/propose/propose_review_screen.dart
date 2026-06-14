import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/address_checkphrase_with_initial.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/propose/propose_done_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ProposeReviewScreen extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final String recipientAddress;
  final String recipientChecksum;
  final BigInt amount;
  final ProposeFeeBreakdown feeBreakdown;

  const ProposeReviewScreen({
    super.key,
    required this.msig,
    required this.recipientAddress,
    required this.recipientChecksum,
    required this.amount,
    required this.feeBreakdown,
  });

  @override
  ConsumerState<ProposeReviewScreen> createState() => _ProposeReviewScreenState();
}

class _ProposeReviewScreenState extends ConsumerState<ProposeReviewScreen> {
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _toggleFlip() async {
    await ref.read(isCurrencyFlippedProvider.notifier).toggle();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final l10n = ref.read(l10nProvider);
    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigProposeAuthReason);
    if (!authed || !mounted) {
      setState(() {
        _submitting = false;
        _errorMessage = l10n.multisigProposeAuthRequired;
      });
      return;
    }
    try {
      final signer = ref
          .read(accountsProvider)
          .value
          ?.firstWhere(
            (a) => a.accountId == widget.msig.myMemberAccountId,
            orElse: () => throw Exception('Member account not found in local wallet'),
          );
      if (signer == null) throw Exception('No signer account available');

      await ref
          .read(transactionSubmissionServiceProvider)
          .proposeTransfer(
            msig: widget.msig,
            signer: signer,
            recipient: widget.recipientAddress,
            amount: widget.amount,
            expiryBlock: widget.feeBreakdown.expiryBlock,
            feeBreakdown: widget.feeBreakdown,
          );

      unawaited(
        RecentAddressesService()
            .addAddress(widget.recipientAddress.trim())
            .catchError((Object e) => debugPrint('Failed to save recent address: $e')),
      );

      if (!mounted) return;
      ref.invalidate(multisigOpenProposalsProvider(widget.msig));
      ref.invalidate(multisigPastProposalsProvider(widget.msig));
      ref.invalidate(multisigCurrentBlockProvider);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProposeDoneScreen(
            msig: widget.msig,
            recipientAddress: widget.recipientAddress,
            recipientChecksum: widget.recipientChecksum,
            amount: widget.amount,
          ),
        ),
      );
    } catch (e, st) {
      debugPrint('Propose submit error: $e $st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = ref.read(l10nProvider).multisigProposeSubmitFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final approxDisplay = ref.watch(txAmountDisplayProvider)(
      widget.amount,
      isSend: true,
      withSignPrefix: false,
      withQuanSymbol: false,
      quanDecimals: 4,
    );
    final shortAddr = AddressFormattingService.formatAddress(widget.recipientAddress);
    final multisigService = ref.watch(multisigServiceProvider);
    final currentBlock = ref.watch(multisigCurrentBlockProvider).value;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigProposeTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(l10n, colors, text, approxDisplay),
          const SizedBox(height: 28),
          Expanded(child: SingleChildScrollView(child: _summary(l10n, shortAddr, fmt, multisigService, currentBlock))),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
          ],
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.multisigProposeCreateButton,
          variant: ButtonVariant.primary,
          isLoading: _submitting,
          isDisabled: _submitting,
          onTap: _submit,
        ),
      ),
    );
  }

  Widget _heroCard(AppLocalizations l10n, AppColorsV2 colors, AppTextTheme text, CurrencyDisplayState approxDisplay) {
    final labelStyle = text.receiveLabel?.copyWith(color: colors.textLabel);

    return SplitCard(
      topChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.multisigProposeReviewProposing, style: labelStyle),
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
          Text(l10n.sendReviewTo, style: labelStyle),
          const SizedBox(height: 16),
          AddressCheckphraseWithInitial(
            recipientChecksum: widget.recipientChecksum,
            recipientAddress: widget.recipientAddress,
          ),
        ],
      ),
    );
  }

  Widget _summary(
    AppLocalizations l10n,
    String shortAddr,
    NumberFormattingService fmt,
    MultisigService multisigService,
    int? currentBlock,
  ) {
    final shownDecimals = AppConstants.decimals;
    final rowSpacing = 4.0;
    final fees = widget.feeBreakdown;
    final valueStyle = context.themeText.transactionDetailRowLabel;

    String formatAmount(BigInt value) =>
        l10n.commonAmountBalance(fmt.formatBalance(value, smartDecimals: shownDecimals), AppConstants.tokenSymbol);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(label: l10n.sendReviewTo, value: shortAddr, valueStyle: valueStyle),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.sendReviewAmount,
          value: formatAmount(widget.amount),
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.multisigProposeThresholdLabel,
          value: '${widget.msig.threshold}/${widget.msig.signers.length}',
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.multisigProposeExpiresLabel,
          valueWidget: MultisigExpiryValue(
            parts: resolveMultisigExpiryParts(
              l10n: l10n,
              expiryBlock: fees.expiryBlock,
              multisigService: multisigService,
              currentBlock: currentBlock,
            ),
            style: valueStyle,
          ),
          valueFlex: 4,
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.sendReviewNetworkFee,
          value: formatAmount(fees.networkFee),
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.multisigProposalDepositLabel,
          value: formatAmount(fees.deposit),
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.multisigProposeFeeRowLabel,
          value: formatAmount(fees.creationFee),
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
        DetailSummaryRow.review(
          label: l10n.multisigProposeMemberTotalLabel,
          value: formatAmount(fees.memberCost),
          valueStyle: valueStyle,
        ),
        SizedBox(height: rowSpacing),
      ],
    );
  }
}
