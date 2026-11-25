import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/models/shell_sheet.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';

/// What the proposal action sheet does: [kind] to [proposal] of [msig].
class ProposalActionTarget {
  final MultisigActionKind kind;
  final MultisigAccount msig;
  final MultisigProposal proposal;

  const ProposalActionTarget({required this.kind, required this.msig, required this.proposal});
}

/// The proposal action the sheet was last opened for. A sheet is opened by
/// its name alone, so what it acts on is held here.
final proposalActionTargetProvider = NotifierProvider<ProposalActionTargetNotifier, ProposalActionTarget?>(
  ProposalActionTargetNotifier.new,
);

class ProposalActionTargetNotifier extends Notifier<ProposalActionTarget?> {
  @override
  ProposalActionTarget? build() => null;

  /// Opens the sheet that does [target]'s action.
  Future<void> open(ProposalActionTarget target) {
    state = target;
    return ref.read(shellSheetProvider.notifier).open(ShellSheet.proposalAction);
  }
}
