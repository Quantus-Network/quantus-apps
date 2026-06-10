import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

void showMultisigCancelConfirmSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
}) {
  BottomSheetContainer.show(
    context,
    builder: (_) => _MultisigCancelConfirmSheet(msig: msig, proposal: proposal),
  );
}

class _MultisigCancelConfirmSheet extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final MultisigProposal proposal;

  const _MultisigCancelConfirmSheet({required this.msig, required this.proposal});

  @override
  ConsumerState<_MultisigCancelConfirmSheet> createState() => _MultisigCancelConfirmSheetState();
}

class _MultisigCancelConfirmSheetState extends ConsumerState<_MultisigCancelConfirmSheet> {
  bool _submitting = false;
  String? _errorMessage;
  BigInt? _networkFee;
  bool _loadingFee = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNetworkFee());
  }

  Future<void> _loadNetworkFee() async {
    try {
      final proposer = ref
          .read(accountsProvider)
          .value
          ?.firstWhere(
            (a) => a.accountId == widget.msig.myMemberAccountId,
            orElse: () => throw Exception('Member account not found in local wallet'),
          );
      if (proposer == null) throw Exception('No proposer account available');

      final fee = await ref
          .read(multisigServiceProvider)
          .estimateCancelFee(msig: widget.msig, signer: proposer, proposalId: widget.proposal.id);

      if (!mounted) return;
      setState(() {
        _networkFee = fee;
        _loadingFee = false;
      });
    } catch (e, st) {
      debugPrint('Cancel fee estimate error: $e $st');
      if (!mounted) return;
      setState(() => _loadingFee = false);
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final l10n = ref.read(l10nProvider);
    final authed = await LocalAuthService().authenticate(localizedReason: l10n.multisigCancelAuthReason);
    if (!authed || !mounted) {
      setState(() {
        _submitting = false;
        _errorMessage = l10n.multisigApproveAuthRequired;
      });
      return;
    }

    try {
      final proposer = ref
          .read(accountsProvider)
          .value
          ?.firstWhere(
            (a) => a.accountId == widget.msig.myMemberAccountId,
            orElse: () => throw Exception('Member account not found in local wallet'),
          );
      if (proposer == null) throw Exception('No proposer account available');

      await ref
          .read(transactionSubmissionServiceProvider)
          .cancelProposal(msig: widget.msig, proposer: proposer, proposal: widget.proposal);

      if (!mounted) return;
      ref.invalidate(multisigOpenProposalsProvider(widget.msig));
      ref.invalidate(multisigCurrentBlockProvider);
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint('Cancel submit error: $e $st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = l10n.multisigCancelFailed;
      });
    }
  }

  String? _networkFeeLabel(AppLocalizations l10n, NumberFormattingService fmt) {
    if (_loadingFee) return '…';
    if (_networkFee == null) return null;
    return l10n.commonAmountBalance(
      fmt.formatBalance(_networkFee!, maxDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final valueStyle = text.transactionDetailRowLabel;
    final networkFeeLabel = _networkFeeLabel(l10n, fmt);

    return BottomSheetContainer(
      title: l10n.multisigCancelConfirmTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(l10n.multisigCancelConfirmBody, style: text.paragraph?.copyWith(color: colors.textPrimary)),
          if (networkFeeLabel != null) ...[
            const SizedBox(height: 16),
            DetailSummaryRow.review(label: l10n.sendReviewNetworkFee, value: networkFeeLabel, valueStyle: valueStyle),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
          ],
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: l10n.multisigCancelConfirmYes,
            variant: ButtonVariant.danger,
            isDisabled: _submitting,
            onTap: _submitting ? null : _confirm,
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: l10n.multisigCancelConfirmKeep,
            variant: ButtonVariant.secondary,
            isDisabled: _submitting,
            onTap: _submitting ? null : () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
