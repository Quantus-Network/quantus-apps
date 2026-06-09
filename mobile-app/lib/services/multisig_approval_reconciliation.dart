import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';

/// Refreshes proposal-related state after indexer confirms an approval.
Future<void> reconcileIndexedApproval(Ref ref, MultisigAccount msig, String approverId) async {
  invalidateMultisigProposals(ref, msig);
  invalidateAccountBalances(ref, {approverId});
}
