import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';

/// Shows the confirmation sheet for executing an approved multisig proposal.
void showMultisigExecuteConfirmSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
}) {
  BottomSheetContainer.show(
    context,
    builder: (_) => MultisigActionConfirmSheet(
      msig: msig,
      proposal: proposal,
      logPrefix: '[MultisigExecute]',
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigExecuteConfirmTitle,
        body: (l10n) => l10n.multisigExecuteConfirmBody,
        confirmLabel: (l10n) => l10n.multisigExecuteConfirmYes,
        dismissLabel: (l10n) => l10n.multisigApproveConfirmNo,
        authReason: (l10n) => l10n.multisigExecuteAuthReason,
        failedMessage: (l10n) => l10n.multisigExecuteFailed,
      ),
      estimateFee: (ref, signer) =>
          ref.read(multisigServiceProvider).estimateExecuteFee(msig: msig, signer: signer, proposalId: proposal.id),
      submit: (ref, signer, fee) => ref
          .read(transactionSubmissionServiceProvider)
          .executeProposal(msig: msig, signer: signer, proposal: proposal, fee: fee),
    ),
  );
}
