import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/split_card.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/approve/approve_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/approve/cancel_confirm_sheet.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ApproveProposalScreen extends ConsumerWidget {
  final MultisigAccount msig;
  final int proposalId;

  const ApproveProposalScreen({super.key, required this.msig, required this.proposalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final async_ = ref.watch(multisigProposalProvider(ProposalKey(msig, proposalId)));

    return async_.when(
      loading: () => ScaffoldBase(
        appBar: V2AppBar(title: l10n.multisigProposalTitle),
        mainContent: const Center(child: Loader()),
      ),
      error: (e, _) => ScaffoldBase(
        appBar: V2AppBar(title: l10n.multisigProposalTitle),
        mainContent: Center(
          child: Text(
            l10n.multisigProposalLoadFailed(e.toString()),
            style: text.detail?.copyWith(color: colors.textError),
          ),
        ),
      ),
      data: (proposal) {
        if (proposal == null) {
          return ScaffoldBase(
            appBar: V2AppBar(title: l10n.multisigProposalTitle),
            mainContent: Center(
              child: Text(
                l10n.multisigProposalNotFound,
                style: text.smallParagraph?.copyWith(color: colors.textTertiary),
              ),
            ),
          );
        }
        return _ApproveScreenLoaded(msig: msig, proposal: proposal);
      },
    );
  }
}

class _ApproveScreenLoaded extends ConsumerWidget {
  final MultisigAccount msig;
  final MultisigProposal proposal;

  const _ApproveScreenLoaded({required this.msig, required this.proposal});

  Future<void> _openApprove(BuildContext context) async {
    await showApproveConfirmSheet(context, msig: msig, proposal: proposal);
  }

  Future<void> _openCancel(BuildContext context) async {
    await showCancelConfirmSheet(context, msig: msig, proposal: proposal);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final fmt = ref.watch(numberFormattingServiceProvider);
    final didApprove = proposal.didApprove(msig.myMemberAccountId);
    final isProposer = proposal.proposer == msig.myMemberAccountId;
    final canCancel = isProposer && proposal.isOpen;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.multisigProposalTitle),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _hero(context, l10n, fmt),
            const SizedBox(height: 28),
            _summary(context, l10n, fmt),
            const SizedBox(height: 24),
            _signersSection(context, l10n),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomContent: proposal.isOpen
          ? ScaffoldBaseBottomContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  QuantusButton.simple(
                    label: didApprove ? l10n.multisigAlreadyApproved : l10n.multisigApproveButton,
                    variant: ButtonVariant.success,
                    isDisabled: didApprove,
                    onTap: didApprove ? null : () => _openApprove(context),
                  ),
                  if (canCancel) ...[
                    const SizedBox(height: 12),
                    QuantusButton.simple(
                      label: l10n.multisigCancelProposalButton,
                      variant: ButtonVariant.danger,
                      onTap: () => _openCancel(context),
                    ),
                  ],
                ],
              ),
            )
          : null,
    );
  }

  Widget _hero(BuildContext context, AppLocalizations l10n, NumberFormattingService fmt) {
    final colors = context.colors;
    final text = context.themeText;
    final labelStyle = text.receiveLabel?.copyWith(color: colors.textLabel);

    return SplitCard(
      topChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sendReviewAmount, style: labelStyle),
          const SizedBox(height: 16),
          Text(
            '${fmt.formatBalance(proposal.amount, maxDecimals: 4)} ${AppConstants.tokenSymbol}',
            style: text.extraLargeTitle?.copyWith(
              color: colors.textPrimary,
              fontFamily: AppTextTheme.fontFamilySecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sendReviewTo, style: labelStyle),
          const SizedBox(height: 12),
          Text(
            AddressFormattingService.formatAddress(proposal.recipient),
            style: text.smallParagraph?.copyWith(color: colors.textPrimary, fontFamily: AppTextTheme.fontFamilySecondary),
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context, AppLocalizations l10n, NumberFormattingService fmt) {
    return Column(
      children: [
        _row(context, l10n.multisigProposalExpiresLabel, DatetimeFormattingService.formatTxDateTime(proposal.expiryAt)),
        const SizedBox(height: 7),
        _row(
          context,
          l10n.multisigProposalThresholdLabel,
          l10n.multisigThresholdOf(proposal.threshold, proposal.signerCount),
        ),
        const SizedBox(height: 7),
        _row(
          context,
          l10n.multisigProposalApprovalsLabel,
          l10n.multisigApprovalsOf(proposal.approvalCount, proposal.threshold),
        ),
        const SizedBox(height: 7),
        _row(
          context,
          l10n.multisigProposalFeeRowLabel,
          '${fmt.formatBalance(proposal.fee, maxDecimals: AppConstants.decimals)} ${AppConstants.tokenSymbol}',
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final labelStyle = context.themeText.transactionDetailRowLabel?.copyWith(color: context.colors.textTertiary);
    final valueStyle = context.themeText.transactionDetailRowLabel;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: labelStyle)),
        const SizedBox(width: 8),
        Flexible(child: Text(value, style: valueStyle, textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _signersSection(BuildContext context, AppLocalizations l10n) {
    final colors = context.colors;
    final text = context.themeText;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.multisigProposalSignersLabel,
            style: text.receiveLabel?.copyWith(color: colors.textLabel),
          ),
          const SizedBox(height: 16),
          ...msig.signers.map((s) {
            final approved = proposal.approvals.contains(s);
            final isYou = s == msig.myMemberAccountId;
            return _SignerRow(
              accountId: s,
              approved: approved,
              isYou: isYou,
              youLabel: l10n.multisigYouLabel,
            );
          }),
        ],
      ),
    );
  }
}

class _SignerRow extends ConsumerStatefulWidget {
  final String accountId;
  final bool approved;
  final bool isYou;
  final String youLabel;
  const _SignerRow({
    required this.accountId,
    required this.approved,
    required this.isYou,
    required this.youLabel,
  });

  @override
  ConsumerState<_SignerRow> createState() => _SignerRowState();
}

class _SignerRowState extends ConsumerState<_SignerRow> {
  String? _checksum;

  @override
  void initState() {
    super.initState();
    ref
        .read(humanReadableChecksumServiceProvider)
        .getHumanReadableName(widget.accountId)
        .then((name) {
      if (mounted) setState(() => _checksum = name);
    }).catchError((Object e) {
      debugPrint('checksum lookup error: $e');
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            widget.approved ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: widget.approved ? colors.success : colors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _checksum ?? '…',
                        style: text.smallParagraph?.copyWith(color: colors.checksum),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isYou) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.useOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.youLabel,
                          style: text.detail?.copyWith(
                            color: colors.accentOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AddressFormattingService.formatAddress(widget.accountId),
                  style: text.detail?.copyWith(
                    color: colors.textTertiary,
                    fontFamily: AppTextTheme.fontFamilySecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
