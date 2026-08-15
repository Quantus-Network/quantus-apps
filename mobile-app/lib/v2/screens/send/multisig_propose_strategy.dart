import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/multisig_expiry_value.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

/// Proposes a transfer from a multisig account. The multisig is a view-only
/// account, so funds leave from [msig] while the proposing member pays the fee.
class MultisigProposeStrategy extends SendStrategy {
  final MultisigAccount msig;

  const MultisigProposeStrategy({required this.msig});

  static final BigInt _estimateFeeAmount = BigInt.from(1000) * NumberFormattingService.scaleFactorBigInt;

  @override
  String? sourceAccountId(WidgetRef ref) => msig.accountId;

  @override
  SendStrings strings(AppLocalizations l10n) => SendStrings(
    flowTitle: l10n.multisigProposeTitle,
    recipientSectionLabel: l10n.multisigProposeSelectRecipientTo,
    amountRecipientCardLabel: l10n.multisigProposeAmountToLabel,
    feeLabel: l10n.multisigProposeFeeLabel,
    feeFetchFailedMessage: l10n.multisigProposeFeeFetchFailed,
    reviewButtonLabel: l10n.multisigProposeReviewButton,
    reviewHeroLabel: l10n.multisigProposeReviewProposing,
    reviewConfirmLabel: l10n.multisigProposeCreateButton,
  );

  @override
  ProviderListenable<AsyncValue<BigInt>> get spendableBalanceProvider => balanceProviderFamily(msig.accountId);

  @override
  bool extraBalancesLoading(WidgetRef ref) =>
      ref.watch(effectiveBalanceProviderFamily(msig.myMemberAccountId)).isLoading;

  // The proposal fee is paid by the member, not from the multisig balance.
  @override
  BigInt feeChargedToBalance(SendFee? fee) => BigInt.zero;

  @override
  ProviderListenable<AsyncValue<BigInt>>? get feePayerBalanceProvider =>
      effectiveBalanceProviderFamily(msig.myMemberAccountId);

  @override
  String? feePayerBalanceLabel(AppLocalizations l10n) => l10n.multisigProposeFeePayerBalanceLabel;

  @override
  Future<SendFee> estimateFee(WidgetRef ref, {required String recipient, required BigInt amount}) async {
    final service = ref.read(multisigServiceProvider);
    final useReal = amount > BigInt.zero && ref.read(substrateServiceProvider).isValidSS58Address(recipient);
    final feeAmount = useReal ? amount : _estimateFeeAmount;

    final accounts = ref.read(accountsProvider).value;
    Account? signer;
    if (accounts != null) {
      for (final account in accounts) {
        if (account.accountId == msig.myMemberAccountId) {
          signer = account;
          break;
        }
      }
    }

    final ProposeFeeBreakdown breakdown;
    if (signer != null) {
      breakdown = await service.estimateProposeFeeBreakdown(
        msig: msig,
        signer: signer,
        recipient: recipient.trim(),
        amount: feeAmount,
      );
    } else {
      final currentBlock = await service.currentBlockNumber();
      breakdown = ProposeFeeBreakdown(
        networkFee: BigInt.zero,
        deposit: service.proposalDeposit,
        creationFee: service.proposalCreationFee(msig.signers.length),
        expiryBlock: currentBlock + service.blocksForDuration(MultisigService.defaultProposalExpiry),
      );
    }
    return ProposeFee(breakdown);
  }

  @override
  String? affordabilityError(WidgetRef ref, SendFee fee, AppLocalizations l10n) {
    final memberBalance = ref.watch(effectiveBalanceProviderFamily(msig.myMemberAccountId)).value;
    if (memberBalance == null) return null;
    return memberBalance < fee.displayFee ? l10n.multisigProposeFeePayerInsufficient : null;
  }

  @override
  List<Widget> reviewRows(
    BuildContext context,
    WidgetRef ref, {
    required String recipientAddress,
    required BigInt amount,
    required SendFee fee,
  }) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final multisigService = ref.watch(multisigServiceProvider);
    final currentBlock = ref.watch(multisigCurrentBlockProvider).value;
    final breakdown = (fee as ProposeFee).breakdown;
    final valueStyle = context.themeText.transactionDetailRowLabel;
    final proposerChecksum = ref.watch(checksumNameProvider(msig.myMemberAccountId)).value ?? '';

    String amt(BigInt v) =>
        l10n.commonAmountBalance(fmt.formatBalance(v, smartDecimals: AppConstants.decimals), AppConstants.tokenSymbol);

    return [
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.multisigProposeProposerLabel,
        valueWidget: _ProposerValue(address: msig.myMemberAccountId, checkphrase: proposerChecksum, style: valueStyle),
        valueFlex: 4,
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
      DetailSummaryRow.review(label: l10n.sendReviewAmount, value: amt(amount), valueStyle: valueStyle),
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.multisigProposeThresholdLabel,
        value: '${msig.threshold}/${msig.signers.length}',
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.multisigProposeExpiresLabel,
        valueWidget: MultisigExpiryValue(
          parts: resolveMultisigExpiryParts(
            l10n: l10n,
            expiryBlock: breakdown.expiryBlock,
            multisigService: multisigService,
            currentBlock: currentBlock,
          ),
          style: valueStyle,
        ),
        valueFlex: 4,
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.sendReviewNetworkFee,
        value: amt(breakdown.networkFee),
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.multisigProposalDepositLabel,
        value: amt(breakdown.deposit),
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.multisigProposeFeeRowLabel,
        value: amt(breakdown.creationFee),
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
      DetailSummaryRow.review(
        label: l10n.multisigProposeMemberTotalLabel,
        value: amt(breakdown.memberCost),
        valueStyle: valueStyle,
      ),
      const SizedBox(height: 4),
    ];
  }

  @override
  Future<SendOutcome> submit(
    WidgetRef ref, {
    required String recipientAddress,
    required String recipientChecksum,
    required BigInt amount,
    required SendFee fee,
    required bool isPayMode,
  }) async {
    final l10n = ref.read(l10nProvider);
    final fmt = ref.read(numberFormattingServiceProvider);
    final breakdown = (fee as ProposeFee).breakdown;

    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigProposeAuthReason);
    if (!authed) return SendFailed(l10n.multisigProposeAuthRequired);

    try {
      final signer = ref
          .read(accountsProvider)
          .value
          ?.firstWhere(
            (a) => a.accountId == msig.myMemberAccountId,
            orElse: () => throw Exception('Member account not found in local wallet'),
          );
      if (signer == null) throw Exception('No signer account available');

      await ref
          .read(transactionSubmissionServiceProvider)
          .proposeTransfer(
            msig: msig,
            signer: signer,
            recipient: recipientAddress,
            amount: amount,
            expiryBlock: breakdown.expiryBlock,
            feeBreakdown: breakdown,
          );

      unawaited(
        RecentAddressesService()
            .addAddress(recipientAddress.trim())
            .catchError((Object e) => quantusPrint('Failed to save recent address: $e')),
      );

      ref.invalidate(multisigOpenProposalsProvider(msig));
      ref.invalidate(multisigPastProposalsProvider(msig));
      ref.invalidate(multisigCurrentBlockProvider);

      return SendSubmitted(
        _terminal(l10n, fmt, recipient: recipientAddress, checksum: recipientChecksum, amount: amount),
      );
    } catch (e, st) {
      quantusPrint('Propose submit error: $e $st');
      return SendFailed(l10n.multisigProposeSubmitFailed);
    }
  }

  SendTerminalContent _terminal(
    AppLocalizations l10n,
    NumberFormattingService fmt, {
    required String recipient,
    required String checksum,
    required BigInt amount,
  }) {
    return SendTerminalContent(
      title: l10n.multisigProposeTitle,
      headline: l10n.multisigProposeDoneHeadline,
      subline: l10n.multisigProposeDoneSubline,
      amountText: l10n.commonAmountBalance(fmt.formatBalance(amount, smartDecimals: 4), AppConstants.tokenSymbol),
      recipientAddress: recipient,
      recipientChecksum: checksum,
      signaturesLabel: l10n.multisigSignaturesCount(1, msig.threshold),
      doneLabel: l10n.multisigDone,
    );
  }
}

class _ProposerValue extends StatelessWidget {
  const _ProposerValue({required this.address, required this.checkphrase, required this.style});

  final String address;
  final String checkphrase;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (checkphrase.isNotEmpty)
          Text(
            checkphrase,
            style: style?.copyWith(color: colors.checksum),
            textAlign: TextAlign.right,
          ),
        const SizedBox(height: 2),
        Text(address, style: style, textAlign: TextAlign.right, softWrap: true),
      ],
    );
  }
}
