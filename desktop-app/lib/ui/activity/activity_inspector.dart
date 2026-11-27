import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/inspector_parts.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_detail.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/activity/wormhole_batches.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_detail.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_detail.dart';
import 'package:wallet_core/activity/activity_facts.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The panel at the window's right that shows what is open: a transaction,
/// as Send's receipt shows one, a multisig's proposal, read only, or the
/// swap being followed. ✕ closes it.
class ActivityInspector extends ConsumerWidget {
  const ActivityInspector({super.key, this.isFocused = false});

  /// Whether the keys are in this panel: its border is lighter.
  final bool isFocused;

  static const closeKey = Key('activity-inspector-close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final opened = ref.watch(openedActivityViewProvider);
    if (opened == null) throw StateError('The panel at the right was drawn with nothing open in it.');

    return Panel(
      title: switch (opened) {
        OpenedTransaction() => l10n.desktopActivityTransaction,
        OpenedProposal() => l10n.multisigProposalTitle,
        OpenedSwap() => l10n.swapTitle,
      },
      isFocused: isFocused,
      trailing: ToolbarAction.symbol(
        key: closeKey,
        symbol: CupertinoIcons.xmark,
        label: l10n.commonClose,
        iconOnly: true,
        onPressed: () => ref.read(openedActivityProvider.notifier).close(),
      ),
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          switch (opened) {
            OpenedTransaction(:final tx) => _TransactionDetail(tx: tx),
            OpenedProposal(:final proposal) => ProposalDetail(proposal: proposal),
            // Its own state for each swap: a question asked of one is not asked of the next.
            OpenedSwap(:final swapId) => SwapDetail(key: ValueKey(swapId), swapId: swapId),
          },
        ],
      ),
    );
  }
}

/// A transaction: where it stands, its amount, what it was and when, who was
/// on the other side, what it cost, its hash to copy, and its page.
class _TransactionDetail extends ConsumerWidget {
  const _TransactionDetail({required this.tx});

  final TransactionEvent tx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final formatting = ref.watch(numberFormattingServiceProvider);
    final account = ref.watch(activeAccountProvider).value?.account;
    if (account == null) throw StateError('A transaction was opened with no open account.');
    final isPrivate = isEncryptedAccount(account);
    final detail = activityDetailOf(tx, accountId: account.accountId, l10n: l10n, isPrivate: isPrivate);
    final facts = activityFactsOf(tx, accountId: account.accountId, l10n: l10n);
    final own = ref.watch(ownAccountsByAddressProvider);
    String money(BigInt value) => l10n.commonAmountBalance(formatting.formatBalance(value), AppConstants.tokenSymbol);
    // A private send's fee is what proving and submitting it cost, as Send says.
    final feeLabel = isPrivate ? l10n.desktopSendTransactionFee : l10n.swapReviewNetworkFee;

    final party = facts.facts.whereType<ActivityPartyFact>().firstOrNull;
    final hash = facts.facts.whereType<ActivityHashFact>().firstOrNull?.hash;
    final fee = facts.facts
        .whereType<ActivityAmountFact>()
        .where((fact) => fact.kind == ActivityFactKind.networkFee)
        .firstOrNull
        ?.amount;
    final isTransfer =
        tx is TransferEvent || tx is PendingTransactionEvent || tx is ReversibleTransferEvent || tx is MinerRewardEvent;

    final status = switch (detail.status) {
      ActivityStatus.completed => inspectorStatusLine(
        context,
        mark: Icon(CupertinoIcons.checkmark_alt, size: 13, color: colors.semanticSage),
        label: detail.status.label(l10n),
        color: colors.semanticSage,
      ),
      // Waiting has a part that moves, unless the system asks for none.
      ActivityStatus.inProcess => inspectorStatusLine(
        context,
        mark: MediaQuery.disableAnimationsOf(context)
            ? null
            : TerminalSpinner(
                style: inspectorCapsStyle(context, color: colors.semanticGlacier).copyWith(letterSpacing: 0),
              ),
        label: detail.status.label(l10n),
        color: colors.semanticGlacier,
      ),
      ActivityStatus.scheduled => inspectorStatusLine(
        context,
        mark: Icon(CupertinoIcons.clock, size: 13, color: colors.semanticGlacier),
        label: detail.status.label(l10n),
        color: colors.semanticGlacier,
        after: l10n.desktopActivityRunsIn(
          activityRowOf(tx, accountId: account.accountId, l10n: l10n, isPrivate: isPrivate).timeLabel,
        ),
      ),
    };

    Widget who(ActivityCounterparty counterparty) => switch (counterparty) {
      ActivityAccount(:final address) || ActivityMultisig(:final address) => inspectorAccount(own[address], address),
      ActivityAggregatedBatch() => Text(
        l10n.activityDetailAggregatedBatch,
        style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.textContent),
      ),
      final ActivityUnnamedCounterparty unnamed => Text(
        unnamed.name(l10n),
        style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.textContent),
      ),
    };

    final rows = <Widget>[
      if (isTransfer && detail.isSend) ...[
        SummaryRow(
          label: inspectorLabel(context, l10n.activityTxFrom),
          value: AccountLabel(account: account, revealsAddress: true),
        ),
        if (fee != null) ...[
          FigureRow(label: feeLabel, value: money(fee)),
          const MenuDivider(),
          const SizedBox(height: 4),
          FigureRow(label: l10n.desktopSendYouPaid, value: money(tx.amount + fee), isStrong: true),
        ],
      ] else if (isTransfer)
        SummaryRow(
          label: inspectorLabel(context, l10n.activityTxTo),
          value: AccountLabel(account: account, revealsAddress: true),
        )
      else
        for (final fact in facts.facts) ?_factRow(context, l10n, fact, own: own, money: money, feeLabel: feeLabel),
    ];

    final amount = facts.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        const SizedBox(height: 14),
        inspectorHeadline(context, amount == null ? '—' : money(amount)),
        const SizedBox(height: 10),
        Text(
          '${detail.title} · ${DatetimeFormattingService.formatTxDateTime(tx.timestamp)}',
          style: context.themeTextV3.body.copyWith(color: colors.textMuted),
        ),
        if (party != null) ...[
          const SizedBox(height: 24),
          CapsText(
            party.kind == ActivityFactKind.to ? l10n.sendTxSubmittedToLabel : l10n.activityTxFrom,
            style: inspectorCapsStyle(context).copyWith(letterSpacing: 1.4),
          ),
          const SizedBox(height: 10),
          who(party.who),
        ],
        const SizedBox(height: 20),
        const MenuDivider(),
        const SizedBox(height: 4),
        ...rows,
        if (hash != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CapsText(
                  l10n.desktopActivityTransaction,
                  style: inspectorCapsStyle(context).copyWith(letterSpacing: 1.4),
                ),
              ),
              CopyAction(text: hash, copyLabel: l10n.receiveCopy, copiedLabel: l10n.desktopCopied),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hash,
            style: context.themeTextV3.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3, color: colors.textMuted),
          ),
        ],
        const SizedBox(height: 20),
        InspectorPageActions(page: detail.status == ActivityStatus.inProcess ? null : detail.explorerUrl),
        // A private send's proof batches, last, so all under their heading is
        // theirs.
        if (tx case final WormholeTransferEvent send when send.batches.isNotEmpty) ...[
          const SizedBox(height: 14),
          // Keyed by the send, so another opens with its batches closed.
          WormholeBatches(key: ValueKey('wormhole-batches-${send.id}'), send: send, feeLabel: feeLabel),
        ],
      ],
    );
  }

  /// The row of one of a proposal's or a multisig's [fact], in the desktop's
  /// words; null for what the page shows elsewhere (who, when, its hash).
  Widget? _factRow(
    BuildContext context,
    AppLocalizations l10n,
    ActivityFact fact, {
    required Map<String, BaseAccount> own,
    required String Function(BigInt value) money,
    required String feeLabel,
  }) {
    final label = switch (fact.kind) {
      ActivityFactKind.to || ActivityFactKind.from || ActivityFactKind.date || ActivityFactKind.hash => null,
      ActivityFactKind.multisig || ActivityFactKind.newMultisig => l10n.activityTxMultisigLabel,
      ActivityFactKind.threshold => l10n.desktopActivityThreshold,
      ActivityFactKind.signers => l10n.desktopActivitySigners,
      ActivityFactKind.creator => l10n.desktopActivityCreatedBy,
      ActivityFactKind.transferAmount => l10n.desktopActivityAmount,
      ActivityFactKind.approvals => l10n.desktopProposeApprovals,
      ActivityFactKind.proposalFee => l10n.desktopProposeFee,
      ActivityFactKind.creationFee => l10n.desktopActivityCreationFee,
      ActivityFactKind.deposit => l10n.desktopProposeDeposit,
      ActivityFactKind.networkFee => feeLabel,
    };
    if (label == null) return null;
    return switch (fact) {
      ActivityAddressFact(:final address) => inspectorAccountRow(context, label, own[address], address),
      ActivityAmountFact(:final amount) => FigureRow(label: label, value: money(amount)),
      ActivityTextFact(:final text) => FigureRow(label: label, value: text),
      ActivityPartyFact() || ActivityTimeFact() || ActivityHashFact() => null,
    };
  }
}
