import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';

/// Shows the confirmation sheet for approving a multisig proposal.
///
/// When more than one local account can still approve, pass [signer] after the
/// user picks an account. Falls back to [MultisigAccount.myMemberAccountId]
/// when [signer] is omitted.
void showMultisigApproveConfirmSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
  Account? signer,
}) {
  BottomSheetContainer.show(
    context,
    builder: (_) => MultisigActionConfirmSheet(
      msig: msig,
      proposal: proposal,
      signer: signer,
      logPrefix: '[MultisigApprove]',
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigApproveConfirmTitle,
        body: (l10n) => l10n.multisigApproveConfirmBody,
        confirmLabel: (l10n) => l10n.multisigApproveConfirmYes,
        dismissLabel: (l10n) => l10n.multisigApproveConfirmNo,
        authReason: (l10n) => l10n.multisigApproveAuthReason,
        failedMessage: (l10n) => l10n.multisigApproveFailed,
      ),
      estimateFee: (ref, resolvedSigner) => ref
          .read(multisigServiceProvider)
          .estimateApproveFee(msig: msig, signer: resolvedSigner, proposalId: proposal.id),
      submit: (ref, resolvedSigner, fee) => ref
          .read(transactionSubmissionServiceProvider)
          .approveProposal(msig: msig, signer: resolvedSigner, proposal: proposal),
    ),
  );
}
