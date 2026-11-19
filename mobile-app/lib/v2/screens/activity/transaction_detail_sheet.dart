import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/dotted_border.dart';
import 'package:wallet_core/activity/activity_detail.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:wallet_core/utils/transaction_event_extension.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/detail_row.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/screens/activity/wormhole_details_screen.dart';

void showTransactionDetailSheet(BuildContext context, TransactionEvent tx, String activeAccountId) {
  if (context.peekTopRouteName == transactionDetailSheetRouteSettings.name) Navigator.pop(context);

  BottomSheetContainer.show(
    context,
    builder: (_) => _TransactionDetailSheet(tx: tx, activeAccountId: activeAccountId),
    routeSettings: transactionDetailSheetRouteSettings,
  );
}

class _TransactionDetailSheet extends ConsumerWidget {
  final TransactionEvent tx;
  final String activeAccountId;

  const _TransactionDetailSheet({required this.tx, required this.activeAccountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final isPrivate = isEncryptedAccount(ref.watch(activeAccountProvider).value?.account);
    final detail = activityDetailOf(tx, accountId: activeAccountId, l10n: l10n, isPrivate: isPrivate);
    final isInProcess = detail.status == ActivityStatus.inProcess;
    final explorerUrl = detail.explorerUrl;
    final canShareExplorer = explorerUrl != null && !isInProcess;

    return BottomSheetContainer(
      title: detail.title,
      trailing: Builder(
        builder: (buttonContext) => IconButton(
          onPressed: canShareExplorer ? () => shareText(buttonContext, explorerUrl) : null,
          icon: Icon(Icons.ios_share, color: canShareExplorer ? colors.textContent : colors.textMuted),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountSection(tx: tx, isSend: detail.isSend, activeAccountId: activeAccountId),
          const SizedBox(height: 20),
          _StatusRow(
            label: l10n.activityDetailStatus,
            value: detail.status.label(l10n),
            color: detail.status == ActivityStatus.completed ? colors.semanticSage : colors.semanticGlacier,
          ),
          const SizedBox(height: 8),
          DottedBorder(
            dashLength: 3,
            gapLength: 8,
            color: colors.borderHairline,
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 8),
          _DetailsSection(tx: tx, isSend: detail.isSend, activeAccountId: activeAccountId),
          const SizedBox(height: 24),
          Center(
            child: ExplorerLink(url: explorerUrl, enabled: !isInProcess),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AmountSection extends ConsumerWidget {
  final TransactionEvent tx;
  final bool isSend;
  final String activeAccountId;

  const _AmountSection({required this.tx, required this.isSend, required this.activeAccountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    final (displayAmount, amountColor) = switch (tx) {
      PendingMultisigCreationEvent(:final totalCost, :final creatorId) when creatorId != activeAccountId => (
        null,
        null,
      ),
      PendingMultisigCreationEvent(:final totalCost) => (totalCost, colors.semanticGlacier),
      MultisigCreatedEvent(:final totalCost, :final creatorId) when creatorId != activeAccountId => (null, null),
      MultisigCreatedEvent(:final totalCost) => (totalCost, colors.textContent),
      MultisigProposalApprovedEvent(:final fee) when fee == null || fee == BigInt.zero => (null, null),
      MultisigProposalApprovedEvent(:final fee) => (fee!, colors.textContent),
      MultisigProposalExecutedEvent(:final fee) when fee == null || fee == BigInt.zero => (null, null),
      MultisigProposalExecutedEvent(:final fee) => (fee!, colors.textContent),
      MultisigProposalCancelledEvent(:final fee) when fee == null || fee == BigInt.zero => (null, null),
      MultisigProposalCancelledEvent(:final fee) => (fee!, colors.textContent),
      PendingMultisigExecutionEvent(:final fee) when fee == null || fee == BigInt.zero => (
        null,
        colors.semanticGlacier,
      ),
      PendingMultisigExecutionEvent(:final fee) => (fee!, colors.semanticGlacier),
      PendingMultisigCancellationEvent(:final fee) when fee == null || fee == BigInt.zero => (
        null,
        colors.semanticGlacier,
      ),
      PendingMultisigCancellationEvent(:final fee) => (fee!, colors.semanticGlacier),
      _ => (tx.amount, isSend ? colors.textContent : colors.semanticSage),
    };

    if (displayAmount == null) {
      return Text('—', style: text.amountHero.copyWith(color: colors.textMuted));
    }

    final amount = ref.watch(txAmountDisplayProvider)(displayAmount, isSend: isSend, withTokenSymbol: false);

    return AmountDisplayWithConversion(amountDisplay: amount, colorizeAmount: false, amountColor: amountColor);
  }
}

class _DetailsSection extends ConsumerWidget {
  final TransactionEvent tx;
  final bool isSend;
  final String activeAccountId;

  const _DetailsSection({required this.tx, required this.isSend, required this.activeAccountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final formattingService = ref.watch(numberFormattingServiceProvider);

    final pendingMultisig = tx;
    if (pendingMultisig is PendingMultisigProposalEvent) {
      return _pendingProposalDetails(pendingMultisig, l10n, formattingService);
    }

    if (tx is MultisigProposalCreatedEvent) {
      return _proposalCreatedDetails(tx as MultisigProposalCreatedEvent, l10n, formattingService);
    }

    if (tx is MultisigProposalApprovedEvent) {
      return _proposalApprovedDetails(tx as MultisigProposalApprovedEvent, l10n, formattingService);
    }

    if (pendingMultisig is PendingMultisigExecutionEvent) {
      return _pendingExecutionDetails(pendingMultisig, l10n, formattingService);
    }

    if (tx is MultisigProposalExecutedEvent) {
      return _proposalExecutedDetails(tx as MultisigProposalExecutedEvent, l10n, formattingService);
    }

    if (pendingMultisig is PendingMultisigCancellationEvent) {
      return _pendingCancellationDetails(pendingMultisig, l10n, formattingService);
    }

    if (tx is MultisigProposalCancelledEvent) {
      return _proposalCancelledDetails(tx as MultisigProposalCancelledEvent, l10n, formattingService);
    }

    if (pendingMultisig is PendingMultisigCreationEvent) {
      return _pendingMultisigDetails(pendingMultisig, l10n, formattingService);
    }

    if (tx is MultisigCreatedEvent) {
      return _multisigDetails(tx as MultisigCreatedEvent, l10n, formattingService);
    }

    final counterparty = isSend ? tx.to : tx.from;
    final counterpartyLabel = isSend ? l10n.activityDetailTo : l10n.activityDetailFrom;
    final dateTime = DatetimeFormattingService.formatTxDateTime(tx.timestamp);

    BigInt? fee;
    if (tx is TransferEvent) fee = (tx as TransferEvent).fee;
    if (tx is PendingTransactionEvent) fee = (tx as PendingTransactionEvent).fee;
    final feeStr = (fee != null && fee != BigInt.zero) ? formatTokenAmount(l10n, formattingService, fee) : null;

    final txHash = tx.extrinsicHash;

    return Column(
      children: [
        if (counterparty.isEmpty)
          DetailRow(
            label: counterpartyLabel,
            value: l10n.activityDetailAggregatedBatch,
            valueKind: DetailValueKind.mono,
          )
        else if (!isSend && tx.isWormhole)
          DetailRow(label: counterpartyLabel, value: l10n.activitySenderEncrypted)
        else
          AddressDetailRow(label: counterpartyLabel, address: counterparty),
        DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (feeStr != null) DetailRow(label: l10n.activityDetailNetworkFee, value: feeStr),
        if (txHash != null) TxHashDetailRow(hash: txHash),
        if (tx case final WormholeTransferEvent send when send.batches.isNotEmpty)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WormholeDetailsScreen(send: send))),
            child: labelValueRow(
              context,
              l10n.activityDetailWormholeDetails,
              Icon(Icons.chevron_right, size: 20, color: context.colorsV3.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _pendingProposalDetails(
    PendingMultisigProposalEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    return _proposalCreationDetails(
      multisigAddress: event.multisigAddress,
      recipient: event.recipient,
      palletFee: event.palletFee,
      deposit: event.deposit,
      fee: event.fee,
      timestamp: event.timestamp,
      extrinsicHash: event.extrinsicHash,
      l10n: l10n,
      formattingService: formattingService,
    );
  }

  Widget _proposalApprovedDetails(
    MultisigProposalApprovedEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = event.multisigAddress;
    final recipientAddress = event.recipient;
    final dateTime = DatetimeFormattingService.formatTxDateTime(event.timestamp);
    final transferAmount = formatTokenAmount(l10n, formattingService, event.amount);
    final networkFeeValue = event.networkFee != BigInt.zero
        ? formatTokenAmount(l10n, formattingService, event.networkFee)
        : null;
    final txHash = event.extrinsicHash;
    final approvalsLabel = event.approvalsOfSignersLabel(l10n.multisigApprovalsOf) ?? event.approvalsCount.toString();

    return Column(
      children: [
        AddressDetailRow(label: l10n.activityDetailMultisigAddress, address: multisig),
        AddressDetailRow(label: l10n.activityDetailTo, address: recipientAddress),
        DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        DetailRow(label: l10n.multisigProposalApprovalsLabel, value: approvalsLabel),
        if (networkFeeValue != null) DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }

  Widget _pendingExecutionDetails(
    PendingMultisigExecutionEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = event.multisigAddress;
    final recipientAddress = event.recipient;
    final transferAmount = formatTokenAmount(l10n, formattingService, event.amount);
    final networkFeeValue = event.fee != null && event.fee != BigInt.zero
        ? formatTokenAmount(l10n, formattingService, event.fee!)
        : null;
    final txHash = event.extrinsicHash;

    return Column(
      children: [
        AddressDetailRow(label: l10n.activityDetailMultisigAddress, address: multisig),
        AddressDetailRow(label: l10n.activityDetailTo, address: recipientAddress),
        DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }

  Widget _pendingCancellationDetails(
    PendingMultisigCancellationEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = event.multisigAddress;
    final recipientAddress = event.recipient;
    final transferAmount = formatTokenAmount(l10n, formattingService, event.amount);
    final networkFeeValue = event.fee != null && event.fee != BigInt.zero
        ? formatTokenAmount(l10n, formattingService, event.fee!)
        : null;
    final txHash = event.extrinsicHash;

    return Column(
      children: [
        AddressDetailRow(label: l10n.activityDetailMultisigAddress, address: multisig),
        AddressDetailRow(label: l10n.activityDetailTo, address: recipientAddress),
        DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }

  Widget _proposalCancelledDetails(
    MultisigProposalCancelledEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = event.multisigAddress;
    final recipientAddress = event.recipient;
    final dateTime = DatetimeFormattingService.formatTxDateTime(event.timestamp);
    final transferAmount = formatTokenAmount(l10n, formattingService, event.amount);
    final networkFeeValue = event.networkFee != BigInt.zero
        ? formatTokenAmount(l10n, formattingService, event.networkFee)
        : null;
    final txHash = event.extrinsicHash;

    return Column(
      children: [
        AddressDetailRow(label: l10n.activityDetailMultisigAddress, address: multisig),
        AddressDetailRow(label: l10n.activityDetailTo, address: recipientAddress),
        DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }

  Widget _proposalExecutedDetails(
    MultisigProposalExecutedEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = event.multisigAddress;
    final recipientAddress = event.recipient;
    final dateTime = DatetimeFormattingService.formatTxDateTime(event.timestamp);
    final transferAmount = formatTokenAmount(l10n, formattingService, event.amount);
    final networkFeeValue = event.networkFee != BigInt.zero
        ? formatTokenAmount(l10n, formattingService, event.networkFee)
        : null;
    final txHash = event.extrinsicHash;

    return Column(
      children: [
        AddressDetailRow(label: l10n.activityDetailMultisigAddress, address: multisig),
        AddressDetailRow(label: l10n.activityDetailTo, address: recipientAddress),
        DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }

  Widget _proposalCreatedDetails(
    MultisigProposalCreatedEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    return _proposalCreationDetails(
      multisigAddress: event.multisigAddress,
      recipient: event.recipient,
      palletFee: event.palletFee,
      deposit: event.deposit,
      fee: event.fee,
      timestamp: event.timestamp,
      extrinsicHash: event.extrinsicHash,
      l10n: l10n,
      formattingService: formattingService,
    );
  }

  Widget _proposalCreationDetails({
    required String multisigAddress,
    required String recipient,
    required BigInt palletFee,
    required BigInt deposit,
    required DateTime timestamp,
    required AppLocalizations l10n,
    required NumberFormattingService formattingService,
    BigInt? fee,
    String? extrinsicHash,
  }) {
    final multisig = multisigAddress;
    final recipientAddress = recipient;
    final dateTime = DatetimeFormattingService.formatTxDateTime(timestamp);
    final palletFeeValue = formatTokenAmount(l10n, formattingService, palletFee);
    final depositValue = formatTokenAmount(l10n, formattingService, deposit);
    final networkFeeValue = fee != null && fee != BigInt.zero ? formatTokenAmount(l10n, formattingService, fee) : null;
    final txHash = extrinsicHash;

    return Column(
      children: [
        AddressDetailRow(label: l10n.activityDetailMultisigAddress, address: multisig),
        AddressDetailRow(label: l10n.activityDetailTo, address: recipientAddress),
        DetailRow(label: l10n.multisigProposalFeeRowLabel, value: palletFeeValue),
        DetailRow(label: l10n.multisigProposalDepositLabel, value: depositValue),
        if (networkFeeValue != null) DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }

  Widget _pendingMultisigDetails(
    PendingMultisigCreationEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    return _multisigFeeDetails(
      l10n: l10n,
      formattingService: formattingService,
      multisigAddress: event.multisigAddress,
      creatorId: event.creatorId,
      threshold: event.threshold,
      signers: event.signers,
      palletFee: event.palletFee,
      networkFee: event.networkFee,
      timestamp: event.timestamp,
    );
  }

  Widget _multisigDetails(
    MultisigCreatedEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final txHash = event.extrinsicHash;

    return _multisigFeeDetails(
      l10n: l10n,
      formattingService: formattingService,
      multisigAddress: event.multisigAddress,
      creatorId: event.creatorId,
      threshold: event.threshold,
      signers: event.signers,
      palletFee: event.palletFee,
      networkFee: event.networkFee,
      timestamp: event.timestamp,
      txHash: txHash,
    );
  }

  Widget _multisigFeeDetails({
    required AppLocalizations l10n,
    required NumberFormattingService formattingService,
    required String multisigAddress,
    required String creatorId,
    required int threshold,
    required List<String> signers,
    required BigInt palletFee,
    required BigInt networkFee,
    required DateTime timestamp,
    String? txHash,
  }) {
    final creatorAddress = creatorId;
    final dateTime = DatetimeFormattingService.formatTxDateTime(timestamp);
    final palletFeeValue = formatTokenAmount(l10n, formattingService, palletFee);
    final networkFeeValue = formatTokenAmount(l10n, formattingService, networkFee);

    return Column(
      children: [
        DetailRow(
          label: l10n.activityDetailMultisigAddress,
          value: multisigAddress,
          valueKind: DetailValueKind.mono,
          copyText: multisigAddress,
          copiedMessage: l10n.receiveCopiedMessage,
        ),
        DetailRow(
          label: l10n.activityDetailMultisigThreshold,
          value: l10n.activityDetailMultisigThresholdValue(threshold, signers.length),
        ),
        DetailRow(label: l10n.activityDetailMultisigSignerCount, value: '${signers.length}'),
        AddressDetailRow(label: l10n.activityDetailMultisigCreator, address: creatorAddress),
        DetailRow(label: l10n.activityDetailMultisigCreationFee, value: palletFeeValue),
        DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null) TxHashDetailRow(hash: txHash),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return labelValueRow(context, label, Text(value, style: context.themeTextV3.labelChip.copyWith(color: color)));
  }
}
