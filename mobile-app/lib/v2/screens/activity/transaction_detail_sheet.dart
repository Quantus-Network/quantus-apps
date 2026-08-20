import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/dotted_border.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:resonance_network_wallet/v2/components/amount_display_with_conversion.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';

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

  bool get _isSend {
    if (_isPendingMultisigProposal ||
        _isPendingMultisigExecution ||
        _isPendingMultisigCancellation ||
        _isMultisigProposalCreated ||
        tx.isMultisigProposalApproved ||
        tx.isMultisigProposalExecuted ||
        tx.isMultisigProposalCancelled ||
        tx is MultisigProposalEvent) {
      return true;
    }
    return tx.from == activeAccountId;
  }

  bool get _isPending => tx is PendingTransactionEvent;
  bool get _isMultisigCreated => tx.isMultisigCreated;
  bool get _isPendingMultisigCreation => tx.isPendingMultisigCreation;
  bool get _isMultisigProposalCreated => tx.isMultisigProposalCreated;
  bool get _isMultisigProposalApproved => tx.isMultisigProposalApproved;
  bool get _isMultisigProposalExecuted => tx.isMultisigProposalExecuted;
  bool get _isMultisigProposalCancelled => tx.isMultisigProposalCancelled;
  bool get _isPendingMultisigProposal => tx.isPendingMultisigProposal;
  bool get _isPendingMultisigExecution => tx.isPendingMultisigExecution;
  bool get _isPendingMultisigCancellation => tx.isPendingMultisigCancellation;

  String _title(AppLocalizations l10n, {required bool isPrivate}) {
    if (_isPendingMultisigProposal) return l10n.activityDetailTitleProposing;
    if (_isPendingMultisigExecution) return l10n.activityDetailTitleExecuting;
    if (_isPendingMultisigCancellation) return l10n.activityDetailTitleCancelling;
    if (_isMultisigProposalCreated) return l10n.activityDetailTitleProposalCreated;
    if (_isMultisigProposalApproved) return l10n.activityDetailTitleProposalApproved;
    if (_isMultisigProposalExecuted) return l10n.activityDetailTitleProposalExecuted;
    if (_isMultisigProposalCancelled) return l10n.activityDetailTitleProposalCancelled;
    if (_isPendingMultisigCreation) return l10n.activityDetailTitleMultisigCreating;
    if (_isMultisigCreated) return l10n.activityDetailTitleMultisigCreated;
    if (_isPending) {
      return isPrivate ? l10n.activityDetailTitlePrivatelySending : l10n.activityDetailTitleSending;
    }
    if (tx.isReversibleScheduled) {
      if (_isSend) return l10n.activityDetailTitleScheduled;
      return isPrivate ? l10n.activityDetailTitlePrivatelyReceiving : l10n.activityDetailTitleReceiving;
    }
    if (_isSend) return isPrivate ? l10n.activityDetailTitlePrivateSent : l10n.activityDetailTitleSent;
    return isPrivate ? l10n.activityDetailTitlePrivateReceived : l10n.activityDetailTitleReceived;
  }

  String _statusLabel(AppLocalizations l10n) {
    if (_isPending ||
        _isPendingMultisigCreation ||
        _isPendingMultisigProposal ||
        _isPendingMultisigExecution ||
        _isPendingMultisigCancellation) {
      return l10n.activityDetailStatusInProcess;
    }
    if (tx.isReversibleScheduled) return l10n.activityDetailStatusScheduled;
    return l10n.activityDetailStatusCompleted;
  }

  Color _statusColor(AppColorsV3 colors) {
    if (_isPending ||
        _isPendingMultisigCreation ||
        _isPendingMultisigProposal ||
        _isPendingMultisigExecution ||
        _isPendingMultisigCancellation ||
        tx.isReversibleScheduled) {
      return colors.semanticGlacier;
    }
    return colors.semanticSage;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final isPrivate = isEncryptedAccount(ref.watch(activeAccountProvider).value?.account);

    return BottomSheetContainer(
      title: _title(l10n, isPrivate: isPrivate),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountSection(tx: tx, isSend: _isSend, activeAccountId: activeAccountId),
          const SizedBox(height: 20),
          _DetailRow(
            label: l10n.activityDetailStatus,
            value: _statusLabel(l10n),
            valueColor: _statusColor(colors),
            valueKind: _DetailValueKind.status,
          ),
          const SizedBox(height: 8),
          DottedBorder(
            dashLength: 3,
            gapLength: 8,
            color: colors.borderHairline,
            child: const SizedBox(width: double.infinity, height: 1),
          ),
          const SizedBox(height: 8),
          _DetailsSection(tx: tx, isSend: _isSend, activeAccountId: activeAccountId),
          const SizedBox(height: 24),
          Center(child: _ExplorerLink(tx: tx)),
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

    final amount = ref.watch(txAmountDisplayProvider)(
      displayAmount,
      isSend: true,
      withTokenSymbol: false,
      customHiddenText: '-----',
    );

    return AmountDisplayWithConversion(amountDisplay: amount, colorizeAmount: false, amountColor: amountColor);
  }
}

class _DetailsSection extends ConsumerWidget {
  final TransactionEvent tx;
  final bool isSend;
  final String activeAccountId;

  const _DetailsSection({required this.tx, required this.isSend, required this.activeAccountId});

  String _formatBalance(AppLocalizations l10n, NumberFormattingService formattingService, BigInt value) {
    return l10n.commonAmountBalance(
      formattingService.formatBalance(value, smartDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
  }

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
    final address = AddressFormattingService.formatActivityDetailAddress(counterparty);
    final dateTime = DatetimeFormattingService.formatTxDateTime(tx.timestamp);

    BigInt? fee;
    if (tx is TransferEvent) fee = (tx as TransferEvent).fee;
    if (tx is PendingTransactionEvent) fee = (tx as PendingTransactionEvent).fee;
    final feeStr = (fee != null && fee != BigInt.zero)
        ? l10n.commonAmountBalance(
            formattingService.formatBalance(fee, smartDecimals: AppConstants.decimals),
            AppConstants.tokenSymbol,
          )
        : null;

    final txHash = tx.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(tx.extrinsicHash!)
        : null;

    return Column(
      children: [
        _DetailRow(
          label: isSend ? l10n.activityDetailTo : l10n.activityDetailFrom,
          value: address,
          valueKind: _DetailValueKind.address,
        ),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (feeStr != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: feeStr),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
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
    final multisig = AddressFormattingService.formatActivityDetailAddress(event.multisigAddress);
    final recipientAddress = AddressFormattingService.formatActivityDetailAddress(event.recipient);
    final dateTime = DatetimeFormattingService.formatTxDateTime(event.timestamp);
    final transferAmount = _formatBalance(l10n, formattingService, event.amount);
    final networkFeeValue = event.networkFee != BigInt.zero
        ? _formatBalance(l10n, formattingService, event.networkFee)
        : null;
    final txHash = event.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(event.extrinsicHash!)
        : null;
    final approvalsLabel = event.approvalsOfSignersLabel(l10n.multisigApprovalsOf) ?? event.approvalsCount.toString();

    return Column(
      children: [
        _DetailRow(label: l10n.activityDetailMultisigAddress, value: multisig, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailTo, value: recipientAddress, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        _DetailRow(label: l10n.multisigProposalApprovalsLabel, value: approvalsLabel),
        if (networkFeeValue != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
      ],
    );
  }

  Widget _pendingExecutionDetails(
    PendingMultisigExecutionEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = AddressFormattingService.formatActivityDetailAddress(event.multisigAddress);
    final recipientAddress = AddressFormattingService.formatActivityDetailAddress(event.recipient);
    final transferAmount = _formatBalance(l10n, formattingService, event.amount);
    final networkFeeValue = event.fee != null && event.fee != BigInt.zero
        ? _formatBalance(l10n, formattingService, event.fee!)
        : null;
    final txHash = event.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(event.extrinsicHash!)
        : null;

    return Column(
      children: [
        _DetailRow(label: l10n.activityDetailMultisigAddress, value: multisig, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailTo, value: recipientAddress, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
      ],
    );
  }

  Widget _pendingCancellationDetails(
    PendingMultisigCancellationEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = AddressFormattingService.formatActivityDetailAddress(event.multisigAddress);
    final recipientAddress = AddressFormattingService.formatActivityDetailAddress(event.recipient);
    final transferAmount = _formatBalance(l10n, formattingService, event.amount);
    final networkFeeValue = event.fee != null && event.fee != BigInt.zero
        ? _formatBalance(l10n, formattingService, event.fee!)
        : null;
    final txHash = event.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(event.extrinsicHash!)
        : null;

    return Column(
      children: [
        _DetailRow(label: l10n.activityDetailMultisigAddress, value: multisig, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailTo, value: recipientAddress, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
      ],
    );
  }

  Widget _proposalCancelledDetails(
    MultisigProposalCancelledEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = AddressFormattingService.formatActivityDetailAddress(event.multisigAddress);
    final recipientAddress = AddressFormattingService.formatActivityDetailAddress(event.recipient);
    final dateTime = DatetimeFormattingService.formatTxDateTime(event.timestamp);
    final transferAmount = _formatBalance(l10n, formattingService, event.amount);
    final networkFeeValue = event.networkFee != BigInt.zero
        ? _formatBalance(l10n, formattingService, event.networkFee)
        : null;
    final txHash = event.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(event.extrinsicHash!)
        : null;

    return Column(
      children: [
        _DetailRow(label: l10n.activityDetailMultisigAddress, value: multisig, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailTo, value: recipientAddress, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
      ],
    );
  }

  Widget _proposalExecutedDetails(
    MultisigProposalExecutedEvent event,
    AppLocalizations l10n,
    NumberFormattingService formattingService,
  ) {
    final multisig = AddressFormattingService.formatActivityDetailAddress(event.multisigAddress);
    final recipientAddress = AddressFormattingService.formatActivityDetailAddress(event.recipient);
    final dateTime = DatetimeFormattingService.formatTxDateTime(event.timestamp);
    final transferAmount = _formatBalance(l10n, formattingService, event.amount);
    final networkFeeValue = event.networkFee != BigInt.zero
        ? _formatBalance(l10n, formattingService, event.networkFee)
        : null;
    final txHash = event.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(event.extrinsicHash!)
        : null;

    return Column(
      children: [
        _DetailRow(label: l10n.activityDetailMultisigAddress, value: multisig, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailTo, value: recipientAddress, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailProposalTransferAmount, value: transferAmount),
        if (networkFeeValue != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
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
    final multisig = AddressFormattingService.formatActivityDetailAddress(multisigAddress);
    final recipientAddress = AddressFormattingService.formatActivityDetailAddress(recipient);
    final dateTime = DatetimeFormattingService.formatTxDateTime(timestamp);
    final palletFeeValue = _formatBalance(l10n, formattingService, palletFee);
    final depositValue = _formatBalance(l10n, formattingService, deposit);
    final networkFeeValue = fee != null && fee != BigInt.zero ? _formatBalance(l10n, formattingService, fee) : null;
    final txHash = extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(extrinsicHash)
        : null;

    return Column(
      children: [
        _DetailRow(label: l10n.activityDetailMultisigAddress, value: multisig, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.activityDetailTo, value: recipientAddress, valueKind: _DetailValueKind.address),
        _DetailRow(label: l10n.multisigProposalFeeRowLabel, value: palletFeeValue),
        _DetailRow(label: l10n.multisigProposalDepositLabel, value: depositValue),
        if (networkFeeValue != null) _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
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
    final txHash = event.extrinsicHash != null
        ? AddressFormattingService.formatActivityDetailExtrinsicHash(event.extrinsicHash!)
        : null;

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
    final formattedMultisigAddress = AddressFormattingService.formatActivityDetailAddress(multisigAddress);
    final creatorAddress = AddressFormattingService.formatActivityDetailAddress(creatorId);
    final dateTime = DatetimeFormattingService.formatTxDateTime(timestamp);
    final palletFeeValue = _formatBalance(l10n, formattingService, palletFee);
    final networkFeeValue = _formatBalance(l10n, formattingService, networkFee);

    return Column(
      children: [
        _DetailRow(
          label: l10n.activityDetailMultisigAddress,
          value: formattedMultisigAddress,
          valueKind: _DetailValueKind.address,
        ),
        _DetailRow(
          label: l10n.activityDetailMultisigThreshold,
          value: l10n.activityDetailMultisigThresholdValue(threshold, signers.length),
        ),
        _DetailRow(label: l10n.activityDetailMultisigSignerCount, value: '${signers.length}'),
        _DetailRow(
          label: l10n.activityDetailMultisigCreator,
          value: creatorAddress,
          valueKind: _DetailValueKind.address,
        ),
        _DetailRow(label: l10n.activityDetailMultisigCreationFee, value: palletFeeValue),
        _DetailRow(label: l10n.activityDetailNetworkFee, value: networkFeeValue),
        _DetailRow(label: l10n.activityDetailDate, value: dateTime),
        if (txHash != null)
          _DetailRow(label: l10n.activityDetailTxHash, value: txHash, valueKind: _DetailValueKind.hash),
      ],
    );
  }
}

enum _DetailValueKind { caption, status, address, hash }

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final _DetailValueKind valueKind;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueKind = _DetailValueKind.caption,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.dataAddress.copyWith(color: colors.textMuted)),
          Text(value, style: _valueStyle(text, colors)),
        ],
      ),
    );
  }

  TextStyle _valueStyle(AppTextThemeV3 text, AppColorsV3 colors) {
    final color = valueColor ?? colors.textContent;
    return switch (valueKind) {
      _DetailValueKind.status => text.labelChip.copyWith(color: color),
      _DetailValueKind.address => text.labelMonogram.copyWith(color: color),
      _DetailValueKind.hash => text.dataAddress.copyWith(color: color),
      _DetailValueKind.caption => text.caption.copyWith(color: color),
    };
  }
}

class _ExplorerLink extends StatelessWidget {
  final TransactionEvent tx;

  const _ExplorerLink({required this.tx});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final isPending =
        tx is PendingTransactionEvent ||
        tx is PendingMultisigCreationEvent ||
        tx is PendingMultisigProposalEvent ||
        tx is PendingMultisigExecutionEvent ||
        tx is PendingMultisigCancellationEvent;
    final color = isPending ? colors.accentFlare.useOpacity(0.3) : colors.accentFlare;

    return ExplorerLink(url: _explorerUrl(), color: color, enabled: !isPending);
  }

  String? _explorerUrl() {
    final isMinerReward = tx.isMinerReward;
    final isMultisigCreated = tx.isMultisigCreated;
    final isProposalCreated = tx.isProposalCreation;
    final isProposalApproved = tx.isMultisigProposalApproved;
    final isProposalExecuted = tx.isMultisigProposalExecuted;
    final isProposalCancelled = tx.isMultisigProposalCancelled;

    String transactionType;
    if (isProposalExecuted) {
      transactionType = 'multisig-proposal-executed';
    } else if (isProposalCancelled) {
      transactionType = 'multisig-proposal-cancelled';
    } else if (isProposalApproved) {
      transactionType = 'multisig-signer-approved';
    } else if (isProposalCreated) {
      transactionType = 'multisig-proposal-created';
    } else if (isMultisigCreated) {
      transactionType = 'multisig-created';
    } else if (isMinerReward) {
      transactionType = 'miner-rewards';
    } else if (tx.isReversibleScheduled) {
      transactionType = 'scheduled-reversible-transactions';
    } else if (tx.isReversibleExecuted) {
      transactionType = 'executed-reversible-transactions';
    } else if (tx.isReversibleCancelled) {
      transactionType = 'cancelled-reversible-transactions';
    } else {
      transactionType = 'immediate-transactions';
    }

    String? path;
    if (tx.extrinsicHash != null) {
      path = '$transactionType/${tx.extrinsicHash}';
    } else if (isMinerReward && tx.blockHash != null) {
      path = '$transactionType/${tx.blockHash}';
    }

    return path == null ? null : '${AppConstants.explorerEndpoint}/$path';
  }
}
