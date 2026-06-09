import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';

/// Refreshes proposal state and balances after an execution is indexed.
Future<void> reconcileIndexedExecution(Ref ref, MultisigAccount msig, PendingMultisigExecutionEvent pending) async {
  invalidateMultisigProposals(ref, msig);
  invalidateAccountBalances(ref, {pending.executorId, msig.accountId});
}
