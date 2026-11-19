import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/multisig_activity.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// A multisig's open proposals, as its home on the phone pins them: the ones
/// this device is still proposing, then the open ones, last changed first. A
/// panel as tall as its rows, up to [maxHeight], then scrolling; with none
/// open it says so.
class OpenProposalsPanel extends ConsumerWidget {
  const OpenProposalsPanel({
    super.key,
    required this.multisig,
    required this.maxHeight,
    this.isFocused = false,
    this.rowsHaveKeys = true,
  });

  final MultisigAccount multisig;
  final double maxHeight;

  /// Whether the keys are in this panel, and whether they are in the lists.
  final bool isFocused;
  final bool rowsHaveKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final view = ref.watch(openProposalsViewProvider);
    if (view == null) throw StateError('Open proposals were drawn for an account that is not a multisig.');
    final localSignerIds = localSignerIdsOf(multisig, ref.watch(accountsProvider).value ?? const <Account>[]);
    final approvals = ref.watch(pendingMultisigApprovalsProvider);
    final executions = ref.watch(pendingMultisigExecutionsProvider);
    final cancellations = ref.watch(pendingMultisigCancellationsProvider);
    final opened = ref.watch(openedActivityViewProvider);

    Widget line(String words, Color color) => Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Text(words, style: text.body.copyWith(color: color)),
    );

    final Widget body = switch (view) {
      AsyncValue(:final value?) when value.proposing.isEmpty && value.open.isEmpty => line(
        l10n.multisigNoOpenProposals,
        colors.textMuted,
      ),
      AsyncValue(:final value?) => LayoutBuilder(
        builder: (context, constraints) {
          final form = ActivityRowForm.of(constraints.maxWidth - 16);
          return ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final pending in value.proposing)
                OpenProposalRowView(
                  key: ValueKey(pending.id),
                  id: pending.id,
                  amount: pending.amount,
                  recipient: pending.recipient,
                  wait: null,
                  needed: multisig.threshold,
                  form: form,
                  l10n: l10n,
                ),
              for (final proposal in value.open)
                OpenProposalRowView(
                  key: ValueKey(proposal.entityId),
                  id: proposal.entityId,
                  amount: proposal.amount,
                  recipient: proposal.recipient,
                  wait: proposalWaitOf(
                    proposal,
                    localSignerIds: localSignerIds,
                    approvals: approvals,
                    executions: executions,
                    cancellations: cancellations,
                  ),
                  approved: proposal.approvalCount,
                  needed: proposal.threshold,
                  form: form,
                  l10n: l10n,
                  isSelected: opened?.id == proposal.entityId,
                  hasFocus: rowsHaveKeys,
                  onTap: () => ref.read(openedActivityProvider.notifier).open(OpenedProposal(proposal)),
                ),
            ],
          );
        },
      ),
      AsyncValue(:final error?) => line(l10n.multisigLoadFailed('$error'), colors.semanticEmber),
      _ => const SizedBox(height: 56),
    };

    return Panel(
      title: l10n.multisigOpenProposals,
      fillsHeight: false,
      isFocused: isFocused,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight - Panel.headerHeight - 1),
        child: Padding(padding: const EdgeInsets.all(8), child: body),
      ),
    );
  }
}

/// One open proposal: what it waits for (a step on its way in glacier, or
/// the phone's PROPOSED / SIGNED badge) over how far its approvals are, then
/// whom it pays, whole, then what it moves. [wait] is null while it is still
/// being proposed.
class OpenProposalRowView extends StatefulWidget {
  const OpenProposalRowView({
    super.key,
    required this.id,
    required this.amount,
    required this.recipient,
    required this.wait,
    this.approved,
    required this.needed,
    required this.form,
    required this.l10n,
    this.isSelected = false,
    this.hasFocus = true,
    this.onTap,
  });

  final String id;
  final BigInt amount;
  final String recipient;
  final ProposalWait? wait;

  /// How many have approved; none is shown while it is being proposed.
  final int? approved;
  final int needed;
  final ActivityRowForm form;
  final AppLocalizations l10n;
  final bool isSelected;

  /// Whether the keys are in the lists; an open row's backing is quieter when not.
  final bool hasFocus;
  final VoidCallback? onTap;

  @override
  State<OpenProposalRowView> createState() => _OpenProposalRowViewState();
}

class _OpenProposalRowViewState extends State<OpenProposalRowView> {
  bool _isHovered = false;

  @override
  void didUpdateWidget(OpenProposalRowView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) showWhenOpened(context);
  }

  bool get _isUnderWay => switch (widget.wait) {
    null || ProposalWait.approving || ProposalWait.executing || ProposalWait.cancelling => true,
    ProposalWait.signed || ProposalWait.proposed || ProposalWait.closed => false,
  };

  Widget _mark(AppColorsV3 colors) {
    final l10n = widget.l10n;
    final word = switch (widget.wait) {
      null => l10n.activityTxProposing,
      ProposalWait.approving => l10n.activityTxApproving,
      ProposalWait.executing => l10n.activityTxExecuting,
      ProposalWait.cancelling => l10n.activityTxCancelling,
      ProposalWait.signed || ProposalWait.proposed || ProposalWait.closed => null,
    };
    if (word != null) {
      return Text(word, style: context.themeTextV3.bodyEmphasis.copyWith(color: colors.semanticGlacier));
    }
    final isSigned = widget.wait == ProposalWait.signed;
    return QuantusBadge(
      label: isSigned ? l10n.multisigStatusApproved : l10n.multisigStatusProposed,
      tone: isSigned ? BadgeTone.sage : BadgeTone.glacier,
    );
  }

  Widget? _approvals(AppColorsV3 colors) {
    final approved = widget.approved;
    if (approved == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ApprovalMarks(approved: approved, needed: widget.needed),
        const SizedBox(width: 6),
        Text(
          widget.l10n.desktopProposeCountOf(approved, widget.needed),
          style: context.themeTextV3.caption.copyWith(
            color: colors.textMuted,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final colors = context.colorsV3;
        final text = context.themeTextV3;
        final formatting = ref.watch(numberFormattingServiceProvider);
        final accent = _isUnderWay ? colors.semanticGlacier : colors.textContent;
        final amount = Text(
          '-${widget.l10n.commonAmountBalance(formatting.formatBalance(widget.amount), AppConstants.tokenSymbol)}',
          style: text.amountRow.copyWith(color: accent, fontFeatures: const [FontFeature.tabularFigures()]),
        );
        final icon = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _isUnderWay ? accent.useOpacity(0.08) : null,
            borderRadius: context.radiusV3.xsBorder,
            border: Border.all(color: _isUnderWay ? accent.useOpacity(0.15) : colors.borderHairline, width: 1.5),
          ),
          child: Center(child: Icon(Icons.how_to_vote_outlined, size: 14, color: accent)),
        );
        final approvals = _approvals(colors);
        final who = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: widget.form == ActivityRowForm.wide ? 58 : 52,
              child: Text(widget.l10n.activityTxTo, style: text.body.copyWith(color: colors.textMuted)),
            ),
            Flexible(child: DesktopAddressCheckphrase(address: widget.recipient, isCompact: true)),
          ],
        );
        final backing = widget.isSelected
            ? colors.textContent.useOpacity(widget.hasFocus ? 0.1 : 0.05)
            : _isHovered
            ? colors.textContent.useOpacity(0.05)
            : null;
        final decoration = BoxDecoration(color: backing, borderRadius: context.radiusV3.smBorder);

        final Widget row = switch (widget.form) {
          ActivityRowForm.wide => Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: decoration,
            child: Row(
              children: [
                icon,
                const SizedBox(width: 12),
                SizedBox(
                  width: 150,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _mark(colors),
                      if (approvals != null) ...[const SizedBox(height: 6), approvals],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: who),
                const SizedBox(width: 16),
                amount,
              ],
            ),
          ),
          ActivityRowForm.tight || ActivityRowForm.brief => Container(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: decoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 28,
                        child: Row(
                          children: [
                            // Where it stands takes the line's room, the
                            // amount closes it.
                            Expanded(
                              child: Row(
                                children: [
                                  _mark(colors),
                                  if (approvals != null) ...[const SizedBox(width: 10), Flexible(child: approvals)],
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            amount,
                          ],
                        ),
                      ),
                      if (widget.form == ActivityRowForm.tight) ...[const SizedBox(height: 2), who],
                    ],
                  ),
                ),
              ],
            ),
          ),
        };

        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: row),
        );
      },
    );
  }
}
