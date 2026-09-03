import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';

/// Shows the confirmation sheet for approving a multisig proposal.
///
/// When more than one local account can still approve, pass [signer] after the
/// user picks an account. Falls back to [MultisigAccount.myMemberAccountId]
/// when [signer] is omitted.
///
/// Keystone signers open the shared hardware QR flow instead of signing locally.
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
      hardwareTelemetryPrefix: 'multisig_approve',
      hardwareCacheIdentity: 'approve|${msig.accountId}|${proposal.id}',
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigApproveConfirmTitle,
        body: (l10n) => l10n.multisigApproveConfirmBody,
        confirmLabel: (l10n) => l10n.multisigApproveConfirmYes,
        dismissLabel: (l10n) => l10n.multisigApproveConfirmNo,
        authReason: (l10n) => l10n.multisigApproveAuthReason,
        failedMessage: (l10n) => l10n.multisigApproveFailed,
      ),
      // Approving resubmits the proposal's inner call, which the chain compares
      // byte-for-byte against what it stored — so the bytes come from the chain,
      // and the sheet shows the caller exactly which call they are approving.
      loadCallBytes: (ref) =>
          ref.read(multisigServiceProvider).fetchProposalCallBytes(msig: msig, proposalId: proposal.id),
      estimateFee: (ref, resolvedSigner, callBytes) => ref
          .read(multisigServiceProvider)
          .estimateApproveFee(msig: msig, signer: resolvedSigner, proposalId: proposal.id, callBytes: callBytes),
      buildCall: (resolvedSigner, callBytes) => MultisigService().buildApproveCall(
        msig: msig,
        proposalId: proposal.id,
        call: requireCallBytes(callBytes, 'Approve'),
      ),
      submit: (ref, resolvedSigner, fee, callBytes) => ref
          .read(transactionSubmissionServiceProvider)
          .approveProposal(msig: msig, signer: resolvedSigner, proposal: proposal, callBytes: callBytes),
      submitExternal: (ref, {required signer, required unsignedData, required signatureWithPublicKey, fee}) => ref
          .read(transactionSubmissionServiceProvider)
          .approveProposalWithExternalSignature(
            msig: msig,
            signer: signer,
            proposal: proposal,
            unsignedData: unsignedData,
            signatureWithPublicKey: signatureWithPublicKey,
          ),
    ),
  );
}
