import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';

/// Shows the confirmation sheet for approving a multisig proposal.
///
/// [signer] approves: when more than one local account can still approve,
/// the one the user picked.
///
/// Keystone signers open the shared hardware QR flow instead of signing locally.
void showMultisigApproveConfirmSheet(
  BuildContext context, {
  required MultisigAccount msig,
  required MultisigProposal proposal,
  required Account signer,
}) {
  BottomSheetContainer.show(
    context,
    builder: (_) => MultisigActionConfirmSheet(
      msig: msig,
      proposal: proposal,
      kind: MultisigActionKind.approve,
      signer: signer,
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigApproveConfirmTitle,
        body: (l10n) => l10n.multisigApproveConfirmBody,
        confirmLabel: (l10n) => l10n.multisigApproveConfirmYes,
        dismissLabel: (l10n) => l10n.multisigApproveConfirmNo,
        failedMessage: (l10n) => l10n.multisigApproveFailed,
      ),
    ),
  );
}
