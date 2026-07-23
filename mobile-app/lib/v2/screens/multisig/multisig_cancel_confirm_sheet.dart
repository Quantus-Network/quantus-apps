import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';

/// Shows the confirmation sheet for cancelling a multisig proposal.
///
/// Keystone signers open the shared hardware QR flow instead of signing locally.
void showMultisigCancelConfirmSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
}) {
  BottomSheetContainer.show(
    context,
    builder: (_) => MultisigActionConfirmSheet(
      msig: msig,
      proposal: proposal,
      logPrefix: '[MultisigCancel]',
      confirmVariant: ButtonVariant.danger,
      hardwareTelemetryPrefix: 'multisig_cancel',
      hardwareCacheIdentity: 'cancel|${msig.accountId}|${proposal.id}',
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigCancelConfirmTitle,
        body: (l10n) => l10n.multisigCancelConfirmBody,
        confirmLabel: (l10n) => l10n.multisigCancelConfirmYes,
        dismissLabel: (l10n) => l10n.multisigCancelConfirmKeep,
        authReason: (l10n) => l10n.multisigCancelAuthReason,
        failedMessage: (l10n) => l10n.multisigCancelFailed,
      ),
      estimateFee: (ref, signer, proposalCall) =>
          ref.read(multisigServiceProvider).estimateCancelFee(msig: msig, signer: signer, proposalId: proposal.id),
      buildCall: (signer, proposalCall) => MultisigService().buildCancelCall(msig: msig, proposalId: proposal.id),
      submit: (ref, signer, fee, proposalCall) => ref
          .read(transactionSubmissionServiceProvider)
          .cancelProposal(msig: msig, proposer: signer, proposal: proposal, fee: fee),
      submitExternal: (ref, {required signer, required unsignedData, required signature, required publicKey, fee}) =>
          ref
              .read(transactionSubmissionServiceProvider)
              .cancelProposalWithExternalSignature(
                msig: msig,
                proposer: signer,
                proposal: proposal,
                unsignedData: unsignedData,
                signature: signature,
                publicKey: publicKey,
                fee: fee,
              ),
    ),
  );
}
