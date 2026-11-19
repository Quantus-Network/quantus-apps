import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/share_service.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/copy_action.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/activity_detail.dart';
import 'package:wallet_core/activity/activity_facts.dart';
import 'package:wallet_core/activity/activity_row.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

/// The panel at the window's right that shows what is open: a transaction,
/// as Send's receipt shows one, or a multisig's proposal, read only. ✕
/// closes it.
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
      title: opened is OpenedProposal ? l10n.multisigProposalTitle : l10n.desktopActivityTransaction,
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
            OpenedProposal(:final proposal) => _ProposalDetail(proposal: proposal),
          },
        ],
      ),
    );
  }
}

/// A small label in capitals, as Send's receipt heads its blocks.
TextStyle _capsStyle(BuildContext context, {Color? color}) => context.themeTextV3.dataAddress.copyWith(
  height: 1,
  letterSpacing: 2.4,
  color: color ?? context.colorsV3.textMuted2,
);

/// The amount a page leads with, or a dash for none.
Widget _headline(BuildContext context, String text) => Text(
  text,
  style: context.themeTextV3.titleHero.copyWith(
    fontSize: 26,
    height: 1.05,
    letterSpacing: -0.65,
    color: context.colorsV3.textWhite,
  ),
);

/// A line of the status: its mark, its word in capitals, and what follows.
Widget _statusLine(BuildContext context, {Widget? mark, required String label, required Color color, String? after}) {
  final caps = _capsStyle(context, color: color);
  return SizedBox(
    height: 14,
    child: Row(
      children: [
        if (mark != null) ...[mark, const SizedBox(width: 8)],
        CapsText(label, style: caps),
        if (after != null) ...[
          const SizedBox(width: 12),
          Text(
            after,
            style: context.themeTextV3.body.copyWith(
              color: context.colorsV3.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    ),
  );
}

/// Who: one of the wallet's own accounts by its badge and name, else the
/// whole address over its checkphrase.
Widget _account(BaseAccount? own, String address) =>
    own == null ? DesktopAddressCheckphrase(address: address, isCompact: true) : AccountLabel(account: own);

/// A row's label, quiet.
Widget _label(BuildContext context, String text) =>
    Text(text, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted));

/// View in Explorer, and, where the system has a share picker, Share: both
/// for [page], unavailable while there is none.
class _PageActions extends ConsumerWidget {
  const _PageActions({required this.page});

  final String? page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final page = this.page;
    return ToolbarActionRow(
      edge: ToolbarActionEdge.leading,
      wraps: true,
      children: [
        ToolbarAction.symbol(
          symbol: CupertinoIcons.arrow_up_right_square,
          label: l10n.desktopViewInExplorer,
          onPressed: page == null ? null : () => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(page))),
        ),
        // Only macOS has a share picker to hand the page to.
        if (defaultTargetPlatform == TargetPlatform.macOS)
          Builder(
            builder: (button) => ToolbarAction.symbol(
              symbol: CupertinoIcons.square_arrow_up,
              label: l10n.componentShare,
              onPressed: page == null
                  ? null
                  : () => unawaited(ref.read(shareTextProvider)(page, origin: button.sharePositionRect())),
            ),
          ),
      ],
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
      ActivityStatus.completed => _statusLine(
        context,
        mark: Icon(CupertinoIcons.checkmark_alt, size: 13, color: colors.semanticSage),
        label: detail.status.label(l10n),
        color: colors.semanticSage,
      ),
      // Waiting has a part that moves, unless the system asks for none.
      ActivityStatus.inProcess => _statusLine(
        context,
        mark: MediaQuery.disableAnimationsOf(context)
            ? null
            : TerminalSpinner(style: _capsStyle(context, color: colors.semanticGlacier).copyWith(letterSpacing: 0)),
        label: detail.status.label(l10n),
        color: colors.semanticGlacier,
      ),
      ActivityStatus.scheduled => _statusLine(
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
      ActivityAccount(:final address) || ActivityMultisig(:final address) => _account(own[address], address),
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
          label: _label(context, l10n.activityTxFrom),
          value: AccountLabel(account: account),
        ),
        if (fee != null) ...[
          FigureRow(label: feeLabel, value: money(fee)),
          const MenuDivider(),
          const SizedBox(height: 4),
          FigureRow(label: l10n.desktopSendYouPaid, value: money(tx.amount + fee), isStrong: true),
        ],
      ] else if (isTransfer)
        SummaryRow(
          label: _label(context, l10n.activityTxTo),
          value: AccountLabel(account: account),
        )
      else
        for (final fact in facts.facts)
          if (_factRow(context, l10n, fact, own: own, money: money, feeLabel: feeLabel) case final row?) row,
    ];

    final amount = facts.amount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        status,
        const SizedBox(height: 14),
        _headline(context, amount == null ? '—' : money(amount)),
        const SizedBox(height: 10),
        Text(
          '${detail.title} · ${DatetimeFormattingService.formatTxDateTime(tx.timestamp)}',
          style: context.themeTextV3.body.copyWith(color: colors.textMuted),
        ),
        if (party != null) ...[
          const SizedBox(height: 24),
          CapsText(
            party.kind == ActivityFactKind.to ? l10n.sendTxSubmittedToLabel : l10n.activityTxFrom,
            style: _capsStyle(context).copyWith(letterSpacing: 1.4),
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
                  style: _capsStyle(context).copyWith(letterSpacing: 1.4),
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
        _PageActions(page: detail.status == ActivityStatus.inProcess ? null : detail.explorerUrl),
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
      ActivityAddressFact(:final address) => SummaryRow(
        label: _label(context, label),
        value: _account(own[address], address),
      ),
      ActivityAmountFact(:final amount) => FigureRow(label: label, value: money(amount)),
      ActivityTextFact(:final text) => FigureRow(label: label, value: text),
      ActivityPartyFact() || ActivityTimeFact() || ActivityHashFact() => null,
    };
  }
}

/// A multisig's proposal, read only: where it stands, what it moves, to whom,
/// how far its approvals are, until when it is open, its deposit, who
/// proposed it, and its page. Approving, executing and cancelling come with
/// the proposals' own feature.
class _ProposalDetail extends ConsumerWidget {
  const _ProposalDetail({required this.proposal});

  final MultisigProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final formatting = ref.watch(numberFormattingServiceProvider);
    final account = ref.watch(activeAccountProvider).value?.account;
    if (account == null) throw StateError('A proposal was opened with no open account.');
    final own = ref.watch(ownAccountsByAddressProvider);
    String money(BigInt value) => l10n.commonAmountBalance(formatting.formatBalance(value), AppConstants.tokenSymbol);

    final (IconData mark, String label, Color color) = switch (proposal.status) {
      MultisigProposalStatus.active ||
      MultisigProposalStatus.approved => (CupertinoIcons.circle, l10n.multisigStatusActive, colors.semanticGlacier),
      MultisigProposalStatus.executed => (
        CupertinoIcons.checkmark_alt,
        l10n.multisigStatusExecuted,
        colors.semanticSage,
      ),
      MultisigProposalStatus.cancelled => (CupertinoIcons.xmark, l10n.multisigStatusCancelled, colors.semanticEmber),
      MultisigProposalStatus.removed => (CupertinoIcons.minus, l10n.multisigStatusRemoved, colors.textMuted),
      MultisigProposalStatus.unknown => (CupertinoIcons.question, l10n.multisigStatusUnknown, colors.textMuted),
    };
    final expiry = proposal.isOpen
        ? resolveMultisigExpiryParts(
            l10n: l10n,
            expiryBlock: proposal.expiryBlock,
            multisigService: ref.read(multisigServiceProvider),
            currentBlock: ref.watch(latestBlockProvider),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusLine(
          context,
          mark: Icon(mark, size: 12, color: color),
          label: label,
          color: color,
        ),
        const SizedBox(height: 14),
        _headline(context, money(proposal.amount)),
        const SizedBox(height: 10),
        Text(
          '${l10n.multisigProposalTitle} · ${DatetimeFormattingService.formatTxDateTime(proposal.createdAt)}',
          style: context.themeTextV3.body.copyWith(color: colors.textMuted),
        ),
        if (proposal.recipient.isNotEmpty) ...[
          const SizedBox(height: 24),
          CapsText(l10n.sendTxSubmittedToLabel, style: _capsStyle(context).copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 10),
          _account(own[proposal.recipient], proposal.recipient),
        ],
        const SizedBox(height: 20),
        const MenuDivider(),
        const SizedBox(height: 4),
        SummaryRow(
          label: _label(context, l10n.activityTxMultisigLabel),
          value: AccountLabel(account: account),
        ),
        SummaryRow(
          label: _label(context, l10n.desktopProposeApprovals),
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ApprovalMarks(approved: proposal.approvalCount, needed: proposal.threshold),
              const SizedBox(width: 9),
              FigureText(l10n.desktopProposeCountOf(proposal.approvalCount, proposal.threshold)),
            ],
          ),
        ),
        if (expiry != null)
          SummaryRow(
            label: _label(context, l10n.desktopProposeExpires),
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (expiry.estimatedDateTime case final date?) ...[
                  Flexible(child: FigureText(date)),
                  const SizedBox(width: 10),
                ],
                Text(
                  expiry.blockLabel,
                  style: context.themeTextV3.body.copyWith(
                    color: expiry.estimatedDateTime == null ? colors.textContent : colors.textMuted2,
                  ),
                ),
              ],
            ),
          ),
        FigureRow(label: l10n.desktopProposeDeposit, value: money(proposal.deposit)),
        SummaryRow(
          label: _label(context, l10n.desktopProposeProposedBy),
          value: _account(own[proposal.proposer], proposal.proposer),
        ),
        const SizedBox(height: 20),
        _PageActions(page: explorerUrl('multisig-proposals/${proposal.explorerProposalId}')),
      ],
    );
  }
}
