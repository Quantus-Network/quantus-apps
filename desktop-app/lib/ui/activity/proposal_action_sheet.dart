import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/providers/proposal_action_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/activity/inspector_parts.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_detail.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/send/send_summary.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/decoded_call_headline.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_action_confirmations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/utils/account_utils.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/multisig_proposal_actions.dart';

/// Approves, executes or cancels a multisig proposal, as Propose sends one:
/// a review of what it does and costs, the computer's approval when it is
/// confirmed, then a receipt that follows what became of it.
///
/// Only an account whose key this app holds signs. Where several could
/// approve, the review offers the choice.
class ProposalActionSheet extends ConsumerStatefulWidget {
  const ProposalActionSheet({super.key});

  static const confirmKey = Key('proposalActionConfirm');
  static const dismissKey = Key('proposalActionDismiss');
  static const doneKey = Key('proposalActionDone');
  static const explorerKey = Key('proposalActionExplorer');

  /// The choice of [accountId] as the account that signs.
  static Key signerKey(String accountId) => ValueKey('proposalActionSigner-$accountId');

  @override
  ConsumerState<ProposalActionSheet> createState() => _ProposalActionSheetState();
}

class _ProposalActionSheetState extends ConsumerState<ProposalActionSheet> {
  late final ProposalActionTarget _target =
      ref.read(proposalActionTargetProvider) ?? (throw StateError('The proposal action sheet opened for no action.'));

  /// Read once: the sheet stays on the account it opened on.
  late final BaseAccount? _account = ref.read(activeAccountProvider).value?.account;

  /// The accounts that could sign it, as the sheet opened, whose key is here:
  /// for an approval, those still to approve; for an execution, any signer,
  /// the member first; for a cancellation, its proposer.
  late final List<Account> _signers = _signersAtOpen();

  late Account _signer = _signers.first;

  /// The hash of the transaction it went out in, once it has.
  String? _hash;

  MultisigActionKind get _kind => _target.kind;
  MultisigProposal get _proposal => _target.proposal;

  MultisigActionRequest get _request =>
      MultisigActionRequest(kind: _kind, msig: _target.msig, proposal: _proposal, signer: _signer);

  List<Account> _signersAtOpen() {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final actions = proposalActionsOf(
      msig: _target.msig,
      proposal: _proposal,
      accounts: accounts,
      currentBlock: ref.read(latestBlockProvider),
      pendingApprovals: ref.read(pendingMultisigApprovalsProvider),
      pendingExecutions: ref.read(pendingMultisigExecutionsProvider),
      pendingCancellations: ref.read(pendingMultisigCancellationsProvider),
    );
    final signers = switch (actions) {
      ProposalOpen(:final canceller) when _kind == MultisigActionKind.cancel => [?canceller],
      ProposalOpen(:final executors) when _kind == MultisigActionKind.execute =>
        executors.where((a) => !a.signsWithHardware).toList(),
      ProposalOpen(:final eligibleApprovers) => eligibleApprovers.where((a) => !a.signsWithHardware).toList(),
      ProposalOver() => const <Account>[],
    };
    if (signers.isEmpty || signers.any((a) => a.signsWithHardware)) {
      throw StateError('The ${_kind.name} sheet opened with no account whose key is here to sign it.');
    }
    return signers;
  }

  Future<void> _confirm() async {
    final outcome = await ref.read(multisigActionConfirmProvider(_request).notifier).confirm();
    if (!mounted) return;
    switch (outcome) {
      case MultisigActionSubmitted(:final hash):
        setState(() => _hash = hash);
      case MultisigActionFailed() || MultisigActionDropped():
        // What stopped it is the confirmation's to say, beside the buttons.
        return;
      case MultisigActionNeedsHardwareSignature():
        throw StateError('The desktop app cannot sign with a Keystone; only accounts whose key is here are offered.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final confirm = ref.watch(multisigActionConfirmProvider(_request));
    final title = switch (_kind) {
      MultisigActionKind.approve => l10n.multisigApproveButton,
      MultisigActionKind.execute => l10n.multisigExecuteButton,
      MultisigActionKind.cancel => l10n.multisigCancelProposalButton,
    };
    final hash = _hash;

    return PopScope(
      // Not while it is being sent; once it has gone out, the receipt closes
      // as any sheet does.
      canPop: hash != null || !confirm.submitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShellSheetHeader(title: title, account: _account),
          const SizedBox(height: 26),
          ...(hash == null ? _review(l10n, confirm) : _receipt(l10n, confirm, hash)),
        ],
      ),
    );
  }

  String _money(BigInt value) {
    final formatting = ref.watch(numberFormattingServiceProvider);
    return ref.watch(l10nProvider).commonAmountBalance(formatting.formatBalance(value), AppConstants.tokenSymbol);
  }

  /// The proposal's call: as the chain stores it once read, the indexer's
  /// until then.
  DecodedCall? _call(MultisigActionConfirmState confirm) =>
      confirm.decodedCall ?? (_proposal.hasUndecodableCall ? null : _proposal.decodedCall);

  /// What the action is done to, in a word: the amount it moves, or the
  /// call's name.
  String _what(DecodedCall? call) {
    if (call == null) return _money(_proposal.amount);
    return DecodedCallHeadline.of(call, amountText: _money).primary;
  }

  /// What it does: the amount and to whom, or the call and its fields.
  List<Widget> _subject(DecodedCall? call) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final own = ref.watch(ownAccountsByAddressProvider);
    final summary = call?.summary;
    if (call != null && summary == null) {
      return [
        inspectorHeadline(context, DecodedCallHeadline.of(call, amountText: _money).primary),
        const SizedBox(height: 14),
        ProposalCallFields(call: call),
      ];
    }
    final (amount, recipient) = summary is TransferSummary
        ? (summary.amount, summary.recipient)
        : (_proposal.amount, _proposal.recipient.isEmpty ? null : _proposal.recipient);
    final formatting = ref.watch(numberFormattingServiceProvider);
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              formatting.formatBalance(amount, smartDecimals: AppConstants.decimals),
              overflow: TextOverflow.ellipsis,
              style: text.displayBalance.copyWith(color: colors.textContent),
            ),
          ),
          const SizedBox(width: 8),
          Text(AppConstants.tokenSymbol, style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
        ],
      ),
      if (recipient != null) ...[
        const SizedBox(height: 22),
        CapsText(ref.watch(l10nProvider).sendTxSubmittedToLabel, style: context.sendCaps()),
        const SizedBox(height: 10),
        inspectorAccount(own[recipient], recipient),
      ],
      if (call != null) ...[const SizedBox(height: 16), ProposalTransferDetails(call: call)],
    ];
  }

  Widget _approvals({required int count, int? after}) {
    final l10n = ref.watch(l10nProvider);
    final needed = _proposal.threshold;
    return SummaryRow(
      label: inspectorLabel(context, l10n.desktopProposeApprovals),
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ApprovalMarks(approved: after ?? count, needed: needed),
          const SizedBox(width: 9),
          FigureText(
            after == null
                ? l10n.desktopProposeCountOf(count, needed)
                : l10n.desktopProposalApprovalsChange(
                    l10n.desktopProposeCountOf(count, needed),
                    l10n.desktopProposeCountOf(after, needed),
                  ),
          ),
        ],
      ),
    );
  }

  /// Who signs: the account, or the choice of them.
  Widget _signsAs(AppLocalizations l10n, {required bool choosing}) {
    if (_signers.length == 1 || !choosing) {
      return SummaryRow(
        label: inspectorLabel(context, choosing ? l10n.desktopProposalSignsAs : l10n.desktopProposalSignedAs),
        value: AccountLabel(account: _signer, revealsAddress: true),
      );
    }
    final colors = context.colorsV3;
    return Padding(
      padding: SummaryRow.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          inspectorLabel(context, l10n.desktopProposalSignsAs),
          const SizedBox(height: 8),
          for (final signer in _signers)
            InkWell(
              key: ProposalActionSheet.signerKey(signer.accountId),
              onTap: ref.watch(multisigActionConfirmProvider(_request)).submitting
                  ? null
                  : () => setState(() => _signer = signer),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Icon(
                      signer.accountId == _signer.accountId
                          ? CupertinoIcons.largecircle_fill_circle
                          : CupertinoIcons.circle,
                      size: 15,
                      color: signer.accountId == _signer.accountId ? colors.accentFlare : colors.textMuted2,
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: AccountLabel(account: signer)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The fee its signer pays, under a line of its own, as Propose says it.
  Widget _total(AppLocalizations l10n, BigInt? fee, {required bool paid}) => fee == null
      ? const SizedBox.shrink()
      : SendTotal(
          rows: [SendReviewText(l10n.swapReviewNetworkFee, _money(fee), kind: SendReviewRowKind.total)],
          label: paid ? l10n.desktopProposePaid : l10n.desktopProposePays,
          signer: _signer,
        );

  List<Widget> _review(AppLocalizations l10n, MultisigActionConfirmState confirm) {
    final colors = context.colorsV3;
    final call = _call(confirm);
    final isCancel = _kind == MultisigActionKind.cancel;
    final fee = confirm.fee;
    final approvalNote = switch (ref.watch(approvalAvailabilityProvider)) {
      AsyncData(:final value) => approvalUnavailableNote(l10n, value),
      AsyncError(:final error) => l10n.desktopApprovalFailed('$error'),
      _ => null,
    };
    final error = switch (confirm.error) {
      null when confirm.cannotPayFee => l10n.multisigProposeFeePayerInsufficient,
      null => null,
      MultisigActionError.approvalRequired => l10n.multisigAuthRequired,
      MultisigActionError.submitFailed => switch (_kind) {
        MultisigActionKind.approve => l10n.multisigApproveFailed,
        MultisigActionKind.execute => l10n.multisigExecuteFailed,
        MultisigActionKind.cancel => l10n.multisigCancelFailed,
      },
      MultisigActionError.feePayerInsufficient => l10n.multisigProposeFeePayerInsufficient,
    };
    final problem = approvalNote ?? error;
    final canConfirm = confirm.canConfirm && approvalNote == null;

    return [
      CapsText(switch (_kind) {
        MultisigActionKind.approve => l10n.desktopProposalApproving,
        MultisigActionKind.execute => l10n.desktopProposalExecuting,
        MultisigActionKind.cancel => l10n.desktopProposalCancelling,
      }, style: isCancel ? context.sendCaps(color: colors.semanticEmber, spacing: 2.4) : context.sendCaps()),
      const SizedBox(height: 12),
      // The lines scroll where the window is too low for them all; what is
      // paid and the buttons stay under them in the sheet.
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._subject(call),
              if (confirm.loadingCall) ...[
                const SizedBox(height: 14),
                Text(l10n.multisigProposalCallLoading, style: context.sendBody()),
              ],
              if (confirm.callUnavailable) ...[
                const SizedBox(height: 14),
                Text(l10n.multisigProposalCallUnavailable, style: context.sendBody(color: colors.semanticEmber)),
              ],
              const SizedBox(height: 18),
              const MenuDivider(),
              const SizedBox(height: 4),
              if (isCancel)
                Padding(
                  padding: SummaryRow.padding,
                  child: Text(l10n.multisigCancelConfirmBody, style: context.sendBody(color: colors.textContent)),
                ),
              SummaryRow(
                label: inspectorLabel(context, l10n.activityTxMultisigLabel),
                value: AccountLabel(account: _target.msig, revealsAddress: true),
              ),
              _signsAs(l10n, choosing: true),
              switch (_kind) {
                MultisigActionKind.approve => _approvals(
                  count: _proposal.approvalCount,
                  after: _proposal.approvalCount + 1,
                ),
                MultisigActionKind.execute => _approvals(count: _proposal.approvalCount),
                MultisigActionKind.cancel => FigureRow(
                  label: l10n.desktopProposalDepositRefunded,
                  value: _money(_proposal.deposit),
                ),
              },
              if (fee != null)
                FigureRow(label: l10n.swapReviewNetworkFee, value: _money(fee))
              else if (confirm.loadingFee)
                FigureRow(label: l10n.swapReviewNetworkFee, value: '…'),
              if (confirm.feeUnavailable)
                Padding(
                  padding: SummaryRow.padding,
                  child: Text(l10n.multisigFeeEstimateUnavailable, style: context.sendBody()),
                ),
            ],
          ),
        ),
      ),
      _total(l10n, fee, paid: false),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: problem == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(problem, style: context.sendBody(color: colors.semanticEmber)),
                  ),
          ),
          SheetButton(
            key: ProposalActionSheet.dismissKey,
            label: isCancel ? l10n.multisigCancelConfirmKeep : l10n.commonCancel,
            kind: SheetButtonKind.secondary,
            isDisabled: confirm.submitting,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: ProposalActionSheet.confirmKey,
            label: switch (_kind) {
              MultisigActionKind.approve => l10n.multisigApproveButton,
              MultisigActionKind.execute => l10n.multisigExecuteButton,
              MultisigActionKind.cancel => l10n.multisigCancelProposalButton,
            },
            kind: isCancel ? SheetButtonKind.destructive : SheetButtonKind.primary,
            isDisabled: !canConfirm,
            isLoading: confirm.submitting,
            onTap: () => unawaited(_confirm()),
          ),
        ],
      ),
    ];
  }

  /// The line over the receipt: what became of the action, as far as known.
  Widget _status(AppLocalizations l10n, MultisigActionConfirmation outcome) {
    final colors = context.colorsV3;
    final (color, label) = switch (outcome) {
      MultisigActionConfirmation.pending => (colors.textMuted, l10n.desktopProposeConfirming),
      MultisigActionConfirmation.confirmed => (
        colors.semanticSage,
        switch (_kind) {
          MultisigActionKind.approve => l10n.desktopProposalApproved,
          MultisigActionKind.execute => l10n.multisigStatusExecuted,
          MultisigActionKind.cancel => l10n.multisigStatusCancelled,
        },
      ),
      MultisigActionConfirmation.executedByAnother => (colors.semanticSand, l10n.desktopProposalExecutedByAnother),
      MultisigActionConfirmation.unconfirmed => (colors.semanticEmber, l10n.desktopProposeNotConfirmed),
    };
    final style = context.sendCaps(color: color, spacing: 2.4);
    const markSize = 13.0;
    final mark = switch (outcome) {
      MultisigActionConfirmation.confirmed => Icon(CupertinoIcons.checkmark_alt, size: markSize, color: color),
      // Waiting has a part that moves, unless the system asks for none.
      MultisigActionConfirmation.pending =>
        MediaQuery.disableAnimationsOf(context) ? null : TerminalSpinner(style: style.copyWith(letterSpacing: 0)),
      MultisigActionConfirmation.executedByAnother || MultisigActionConfirmation.unconfirmed => Icon(
        CupertinoIcons.exclamationmark_circle,
        size: markSize,
        color: color,
      ),
    };
    // As high with one mark as with another, or with none: what is under it
    // stays where it is when the outcome is learned.
    return SizedBox(
      height: markSize,
      child: Row(
        children: [
          if (mark != null) ...[mark, const SizedBox(width: 8)],
          CapsText(label, style: style),
        ],
      ),
    );
  }

  List<Widget> _receipt(AppLocalizations l10n, MultisigActionConfirmState confirm, String hash) {
    final colors = context.colorsV3;
    final outcome = ref.watch(multisigActionConfirmationProvider(hash));
    final call = _call(confirm);
    final what = _what(call);
    final settled = outcome == MultisigActionConfirmation.confirmed;
    final after = _proposal.approvalCount + 1;
    final title = switch ((_kind, outcome)) {
      (MultisigActionKind.approve, MultisigActionConfirmation.confirmed) => l10n.desktopProposalApprovedTitle(what),
      (MultisigActionKind.approve, _) => l10n.desktopProposalApprovingTitle(what),
      (MultisigActionKind.execute, MultisigActionConfirmation.confirmed) ||
      (
        MultisigActionKind.execute,
        MultisigActionConfirmation.executedByAnother,
      ) => l10n.desktopProposalExecutedTitle(what),
      (MultisigActionKind.execute, _) => l10n.desktopProposalExecutingTitle(what),
      (MultisigActionKind.cancel, MultisigActionConfirmation.confirmed) => l10n.desktopProposalCancelledTitle,
      (MultisigActionKind.cancel, _) => l10n.desktopProposalCancellingTitle(what),
    };
    final (body, bodyColor) = switch (outcome) {
      MultisigActionConfirmation.pending => (
        switch (_kind) {
          MultisigActionKind.approve => l10n.desktopProposalApprovalWaiting,
          MultisigActionKind.execute => l10n.desktopProposalExecutionWaiting,
          MultisigActionKind.cancel => l10n.desktopProposalCancellationWaiting,
        },
        null,
      ),
      MultisigActionConfirmation.confirmed => (
        switch (_kind) {
          MultisigActionKind.approve =>
            after >= _proposal.threshold
                ? l10n.desktopProposalReadyToExecute
                : l10n.desktopProposalApprovalsNeeded(_proposal.threshold - after),
          MultisigActionKind.execute => l10n.desktopProposalExecutedDone,
          MultisigActionKind.cancel => l10n.desktopProposalCancelledDone,
        },
        null,
      ),
      MultisigActionConfirmation.executedByAnother => (l10n.desktopProposalExecutedByAnotherBody, null),
      MultisigActionConfirmation.unconfirmed => (
        switch (_kind) {
          MultisigActionKind.approve => l10n.multisigApprovalTimeoutToast,
          MultisigActionKind.execute => l10n.multisigExecutionTimeoutToast,
          MultisigActionKind.cancel => l10n.multisigCancelTimeoutToast,
        },
        colors.semanticEmber,
      ),
    };
    final page = explorerUrl('multisig-proposals/${_proposal.explorerProposalId}');
    final fee = confirm.fee;

    return [
      _status(l10n, outcome),
      const SizedBox(height: 14),
      Text(
        title,
        style: context.themeTextV3.titleHero.copyWith(
          fontSize: 26,
          height: 1.05,
          letterSpacing: -0.65,
          color: colors.textWhite,
        ),
      ),
      const SizedBox(height: 10),
      Text(body, style: context.sendBody(color: bodyColor)),
      const SizedBox(height: 22),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (call != null && call.summary is TransferSummary) ...[
                // Who it pays, without the amount the headline already says.
                ..._subject(call).skip(2),
                const SizedBox(height: 18),
              ],
              const MenuDivider(),
              const SizedBox(height: 4),
              SummaryRow(
                label: inspectorLabel(context, l10n.activityTxMultisigLabel),
                value: AccountLabel(account: _target.msig, revealsAddress: true),
              ),
              _signsAs(l10n, choosing: false),
              if (_kind == MultisigActionKind.approve) _approvals(count: settled ? after : _proposal.approvalCount),
              if (fee != null) FigureRow(label: l10n.swapReviewNetworkFee, value: _money(fee)),
            ],
          ),
        ),
      ),
      _total(
        l10n,
        fee,
        paid:
            outcome == MultisigActionConfirmation.confirmed || outcome == MultisigActionConfirmation.executedByAnother,
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          ToolbarActionRow(
            edge: ToolbarActionEdge.leading,
            children: [
              ToolbarAction.symbol(
                key: ProposalActionSheet.explorerKey,
                symbol: CupertinoIcons.arrow_up_right_square,
                label: l10n.desktopViewInExplorer,
                onPressed: () => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(page))),
              ),
            ],
          ),
          const Spacer(),
          SheetButton(
            key: ProposalActionSheet.doneKey,
            label: l10n.commonDone,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ];
  }
}
