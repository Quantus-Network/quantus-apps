import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/dotted_border.dart';
import 'package:wallet_core/activity/activity_detail.dart';
import 'package:wallet_core/activity/activity_facts.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/currency_display_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
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
    final facts = activityFactsOf(tx, accountId: activeAccountId, l10n: l10n);
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
          _AmountSection(facts: facts, isSend: detail.isSend),
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
          _DetailsSection(tx: tx, facts: facts),
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

/// The amount the sheet leads with, as wallet_core's [ActivityFacts] give it:
/// a dash when there is none.
class _AmountSection extends ConsumerWidget {
  final ActivityFacts facts;
  final bool isSend;

  const _AmountSection({required this.facts, required this.isSend});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.themeTextV3;
    final colors = context.colorsV3;

    final amount = facts.amount;
    if (amount == null) {
      return Text('—', style: text.amountHero.copyWith(color: colors.textMuted));
    }

    final display = ref.watch(txAmountDisplayProvider)(amount, isSend: isSend, withTokenSymbol: false);
    final color = switch (facts.highlight) {
      ActivityHighlight.none => colors.textContent,
      ActivityHighlight.arriving => colors.semanticSage,
      ActivityHighlight.leaving => colors.semanticGlacier,
    };

    return AmountDisplayWithConversion(amountDisplay: display, colorizeAmount: false, amountColor: color);
  }
}

/// The sheet's rows: each of wallet_core's facts in order, then, for a
/// private send in several batches, the way to their details.
class _DetailsSection extends ConsumerWidget {
  final TransactionEvent tx;
  final ActivityFacts facts;

  const _DetailsSection({required this.tx, required this.facts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final formattingService = ref.watch(numberFormattingServiceProvider);

    return Column(
      children: [
        for (final fact in facts.facts) _row(l10n, formattingService, fact),
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

  Widget _row(AppLocalizations l10n, NumberFormattingService formattingService, ActivityFact fact) {
    final label = _labelOf(l10n, fact.kind);
    return switch (fact) {
      ActivityPartyFact(:final who) => switch (who) {
        ActivityAccount(:final address) ||
        ActivityMultisig(:final address) => AddressDetailRow(label: label, address: address),
        ActivityAggregatedBatch() => DetailRow(
          label: label,
          value: l10n.activityDetailAggregatedBatch,
          valueKind: DetailValueKind.mono,
        ),
        ActivityEncryptedSender() => DetailRow(label: label, value: who.name(l10n)),
      },
      // The multisig being made is shown whole.
      ActivityAddressFact(kind: ActivityFactKind.newMultisig, :final address) => DetailRow(
        label: label,
        value: address,
        valueKind: DetailValueKind.mono,
        copyText: address,
        copiedMessage: l10n.receiveCopiedMessage,
      ),
      ActivityAddressFact(:final address) => AddressDetailRow(label: label, address: address),
      ActivityAmountFact(:final amount) => DetailRow(
        label: label,
        value: formatTokenAmount(l10n, formattingService, amount),
      ),
      ActivityTextFact(:final text) => DetailRow(label: label, value: text),
      ActivityTimeFact(:final time) => DetailRow(label: label, value: DatetimeFormattingService.formatTxDateTime(time)),
      ActivityHashFact(:final hash) => TxHashDetailRow(hash: hash),
    };
  }

  String _labelOf(AppLocalizations l10n, ActivityFactKind kind) => switch (kind) {
    ActivityFactKind.to => l10n.activityDetailTo,
    ActivityFactKind.from => l10n.activityDetailFrom,
    ActivityFactKind.multisig || ActivityFactKind.newMultisig => l10n.activityDetailMultisigAddress,
    ActivityFactKind.threshold => l10n.activityDetailMultisigThreshold,
    ActivityFactKind.signers => l10n.activityDetailMultisigSignerCount,
    ActivityFactKind.creator => l10n.activityDetailMultisigCreator,
    ActivityFactKind.transferAmount => l10n.activityDetailProposalTransferAmount,
    ActivityFactKind.approvals => l10n.multisigProposalApprovalsLabel,
    ActivityFactKind.proposalFee => l10n.multisigProposalFeeRowLabel,
    ActivityFactKind.creationFee => l10n.activityDetailMultisigCreationFee,
    ActivityFactKind.deposit => l10n.multisigProposalDepositLabel,
    ActivityFactKind.networkFee => l10n.activityDetailNetworkFee,
    ActivityFactKind.date => l10n.activityDetailDate,
    ActivityFactKind.hash => l10n.activityDetailTxHash,
  };
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
