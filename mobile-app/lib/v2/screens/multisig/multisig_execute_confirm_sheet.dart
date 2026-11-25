import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';

/// Shows the confirmation sheet for executing an approved multisig proposal,
/// signed by [signer]: when more than one local account can execute, the one
/// the user picked.
///
/// Keystone signers open the shared hardware QR flow instead of signing locally.
void showMultisigExecuteConfirmSheet(
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
      kind: MultisigActionKind.execute,
      signer: signer,
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigExecuteConfirmTitle,
        body: (l10n) => l10n.multisigExecuteConfirmBody,
        confirmLabel: (l10n) => l10n.multisigExecuteConfirmYes,
        dismissLabel: (l10n) => l10n.multisigApproveConfirmNo,
        failedMessage: (l10n) => l10n.multisigExecuteFailed,
      ),
    ),
  );
}
