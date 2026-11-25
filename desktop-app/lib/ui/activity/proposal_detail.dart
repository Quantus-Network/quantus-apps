import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/inspector_parts.dart';
import 'package:quantus_desktop_wallet/ui/activity/proposal_actions.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/approval_marks.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/activity/decoded_call_headline.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/utils/explorer_url.dart';
import 'package:wallet_core/utils/multisig_expiry.dart';

/// A multisig's proposal: where it stands; what it does, by its amount and
/// recipient or, for a call that moves nothing, by the call and its fields;
/// what this wallet can do with it, before the details; how far its approvals
/// are and who gave them; until when it is open; what proposing it cost; who
/// proposed it; and its page.
class ProposalDetail extends ConsumerWidget {
  const ProposalDetail({super.key, required this.proposal});

  final MultisigProposal proposal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final formatting = ref.watch(numberFormattingServiceProvider);
    final account = ref.watch(activeAccountProvider).value?.account;
    if (account is! MultisigAccount) throw StateError('A proposal was opened with no multisig open: $account');
    final own = ref.watch(ownAccountsByAddressProvider);
    final currentBlock = ref.watch(latestBlockProvider);
    String money(BigInt value) => l10n.commonAmountBalance(formatting.formatBalance(value), AppConstants.tokenSymbol);

    final isExpired = currentBlock != null && proposal.expired(currentBlock);
    final (IconData mark, String label, Color color) = switch (proposal.status) {
      MultisigProposalStatus.active || MultisigProposalStatus.approved when isExpired => (
        CupertinoIcons.clock,
        l10n.desktopProposalExpired,
        colors.semanticSand,
      ),
      MultisigProposalStatus.active => (CupertinoIcons.circle, l10n.multisigStatusActive, colors.semanticGlacier),
      MultisigProposalStatus.approved => (
        CupertinoIcons.checkmark_seal,
        l10n.desktopProposalApproved,
        colors.semanticGlacier,
      ),
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
            currentBlock: currentBlock,
          )
        : null;
    final date = DatetimeFormattingService.formatTxDateTime(proposal.createdAt);
    // A call that moves nothing is named, never shown as an amount of zero;
    // one this wallet cannot read says so.
    final call = proposal.hasUndecodableCall ? null : proposal.decodedCall;
    final named = call != null && call.summary == null
        ? DecodedCallHeadline.of(call, amountText: (_) => throw StateError('A call that moves nothing has no amount.'))
        : null;
    final lineStyle = context.themeTextV3.body.copyWith(color: colors.textMuted);
    final networkFee = proposal.networkFee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        inspectorStatusLine(
          context,
          mark: Icon(mark, size: 12, color: color),
          label: label,
          color: color,
        ),
        const SizedBox(height: 14),
        if (proposal.hasUndecodableCall) ...[
          inspectorHeadline(context, l10n.multisigProposalInvalid, color: colors.semanticEmber),
          const SizedBox(height: 10),
          Text('${l10n.multisigProposalTitle} · $date', style: lineStyle),
          const SizedBox(height: 14),
          Text(l10n.desktopProposalUnreadable, style: context.themeTextV3.body.copyWith(color: colors.textContent)),
        ] else if (named != null) ...[
          inspectorHeadline(context, named.primary),
          const SizedBox(height: 10),
          Text('${named.palletSubtitle ?? l10n.multisigProposalTitle} · $date', style: lineStyle),
          const SizedBox(height: 14),
          ProposalCallFields(call: call!),
        ] else ...[
          inspectorHeadline(context, money(proposal.amount)),
          const SizedBox(height: 10),
          Text('${l10n.multisigProposalTitle} · $date', style: lineStyle),
          if (proposal.recipient.isNotEmpty) ...[
            const SizedBox(height: 24),
            CapsText(l10n.sendTxSubmittedToLabel, style: inspectorCapsStyle(context).copyWith(letterSpacing: 1.4)),
            const SizedBox(height: 10),
            inspectorAccount(own[proposal.recipient], proposal.recipient),
          ],
          if (call != null) ...[const SizedBox(height: 16), ProposalTransferDetails(call: call)],
        ],
        ProposalActionsBar(msig: account, proposal: proposal),
        const SizedBox(height: 20),
        const MenuDivider(),
        const SizedBox(height: 4),
        SummaryRow(
          label: inspectorLabel(context, l10n.activityTxMultisigLabel),
          value: AccountLabel(account: account, revealsAddress: true),
        ),
        SummaryRow(
          label: inspectorLabel(context, l10n.desktopProposeApprovals),
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ApprovalMarks(approved: proposal.approvalCount, needed: proposal.threshold),
              const SizedBox(width: 9),
              FigureText(l10n.desktopProposeCountOf(proposal.approvalCount, proposal.threshold)),
            ],
          ),
        ),
        // Who gave the approvals, under the count they make.
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final signer in account.signers)
                ProposalSignerRow(address: signer, hasApproved: proposal.didApprove(signer)),
            ],
          ),
        ),
        if (expiry != null)
          SummaryRow(
            label: inspectorLabel(context, isExpired ? l10n.desktopProposalExpired : l10n.desktopProposeExpires),
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
        FigureRow(label: l10n.desktopProposeFee, value: money(proposal.palletFee)),
        FigureRow(label: l10n.desktopProposeDeposit, value: money(proposal.deposit)),
        if (networkFee != null && networkFee != BigInt.zero)
          FigureRow(label: l10n.swapReviewNetworkFee, value: money(networkFee)),
        inspectorAccountRow(context, l10n.desktopProposeProposedBy, own[proposal.proposer], proposal.proposer),
        const SizedBox(height: 20),
        InspectorPageActions(page: explorerUrl('multisig-proposals/${proposal.explorerProposalId}')),
      ],
    );
  }
}

/// One of a multisig's signers on its proposal's page: one of the wallet's
/// own accounts by its badge and name, marked as the person's own, any other
/// by its whole address over its checkphrase; and at the line's end whether
/// they approved it.
class ProposalSignerRow extends ConsumerWidget {
  const ProposalSignerRow({super.key, required this.address, required this.hasApproved});

  final String address;
  final bool hasApproved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final own = ref.watch(ownAccountsByAddressProvider)[address];
    final mark = Icon(
      hasApproved ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
      size: 15,
      color: hasApproved ? colors.semanticSage : colors.textMuted2,
      semanticLabel: hasApproved ? l10n.desktopProposalApproved : null,
    );
    if (own != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(child: AccountLabel(account: own, revealsAddress: true)),
                  const SizedBox(width: 8),
                  Text(l10n.desktopAccountInfoYou, style: context.themeTextV3.body.copyWith(color: colors.textMuted2)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            mark,
          ],
        ),
      );
    }
    // The address takes the whole line; the mark ends the checkphrase's,
    // which is shorter.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Stack(
        children: [
          DesktopAddressCheckphrase(address: address, isCompact: true),
          PositionedDirectional(end: 0, bottom: 1, child: mark),
        ],
      ),
    );
  }
}

/// Every field of a proposal's [call], in the panel's own rows: an address
/// under its label, whole, or by its badge and name when the wallet holds it;
/// a hash, bytes or text under its label, whole; a figure at its line's end;
/// a group or a nested call indented under its label.
///
/// See also [ProposalTransferDetails], for a call headed by what it moves.
class ProposalCallFields extends ConsumerWidget {
  const ProposalCallFields({super.key, required this.call, this.except = const []});

  final DecodedCall call;

  /// Fields said already, where the call is headed by what it moves; left
  /// out by identity, so another field of an equal value is still listed.
  final List<CallField> except;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final formatting = ref.watch(numberFormattingServiceProvider);
    final own = ref.watch(ownAccountsByAddressProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final field in call.fields)
          if (!except.any((said) => identical(said, field))) _field(context, l10n, formatting, own, field),
      ],
    );
  }

  Widget _field(
    BuildContext context,
    AppLocalizations l10n,
    NumberFormattingService formatting,
    Map<String, BaseAccount> own,
    CallField field,
  ) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    Widget withNote(Widget row, String? note) => note == null
        ? row
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              row,
              Text(note, style: text.caption.copyWith(color: colors.textMuted)),
            ],
          );
    Widget under(String label, Widget value) => Padding(
      padding: SummaryRow.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [inspectorLabel(context, label), const SizedBox(height: 6), value],
      ),
    );
    Widget indented(String label, List<Widget> children) => under(
      label,
      Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      ),
    );

    return switch (field) {
      ValueField(kind: ValueKind.address) => withNote(
        inspectorAccountRow(context, field.label, own[field.value], field.value),
        field.note,
      ),
      ValueField(kind: ValueKind.hash || ValueKind.bytes) => withNote(
        under(
          field.label,
          Text(
            field.value,
            style: text.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3, color: colors.textContent),
          ),
        ),
        field.note,
      ),
      ValueField(kind: ValueKind.text) => withNote(
        under(field.label, Text(field.value, style: text.body.copyWith(color: colors.textContent))),
        field.note,
      ),
      ValueField() => withNote(FigureRow(label: field.label, value: field.value), field.note),
      AmountField() => withNote(
        FigureRow(
          label: field.label,
          value: field.assetId == null
              ? l10n.commonAmountBalance(formatting.formatBalance(field.token), AppConstants.tokenSymbol)
              : '${field.token} (asset #${field.assetId}, raw units)',
        ),
        field.note,
      ),
      FieldGroup(:final items) => indented(field.label, [
        for (final item in items) _field(context, l10n, formatting, own, item),
      ]),
      NestedCallField(call: final nested) => withNote(
        indented(field.label, [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              DecodedCallHeadline.of(
                nested,
                amountText: (token) =>
                    l10n.commonAmountBalance(formatting.formatBalance(token), AppConstants.tokenSymbol),
              ).primary,
              style: text.bodyEmphasis.copyWith(color: colors.textContent),
            ),
          ),
          // Which call it is: two that read alike in words, such as the
          // transfers that keep the sender alive and that may not, differ.
          Text(
            nested.displayTitle,
            style: text.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3, color: colors.textMuted),
          ),
          for (final item in nested.fields) _field(context, l10n, formatting, own, item),
        ]),
        field.note,
      ),
    };
  }
}

/// What a call headed by the amount it moves and to whom is, beyond those:
/// its runtime name, so a reversible transfer or one that may close the
/// sender's account is told from a plain one, and every field the headline
/// does not say, such as how long the transfer stays reversible.
class ProposalTransferDetails extends StatelessWidget {
  const ProposalTransferDetails({super.key, required this.call});

  final DecodedCall call;

  @override
  Widget build(BuildContext context) {
    final summary = call.summary ?? (throw StateError('Only a call headed by what it moves has transfer details.'));
    final said = [?summary.amountField, if (summary.recipient != null) ?summary.recipientField];
    final rest = call.fields.where((field) => !said.any((s) => identical(s, field)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          call.displayTitle,
          style: context.themeTextV3.dataAddress.copyWith(
            height: 1.3,
            letterSpacing: 0.3,
            color: context.colorsV3.textMuted,
          ),
        ),
        if (rest.isNotEmpty) ...[const SizedBox(height: 8), ProposalCallFields(call: call, except: said)],
      ],
    );
  }
}
