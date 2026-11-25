import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/multisig/multisig_action_confirm_sheet.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';

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
      kind: MultisigActionKind.cancel,
      confirmVariant: ButtonVariant.danger,
      labels: MultisigConfirmSheetLabels(
        title: (l10n) => l10n.multisigCancelConfirmTitle,
        body: (l10n) => l10n.multisigCancelConfirmBody,
        confirmLabel: (l10n) => l10n.multisigCancelConfirmYes,
        dismissLabel: (l10n) => l10n.multisigCancelConfirmKeep,
        failedMessage: (l10n) => l10n.multisigCancelFailed,
      ),
    ),
  );
}
