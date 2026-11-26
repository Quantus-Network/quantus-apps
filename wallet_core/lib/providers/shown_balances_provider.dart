import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/utils/multisig_local_signers.dart';

/// The accounts whose balances the app has on screen besides the active
/// account's. Whatever refreshes the active account's balance refreshes
/// theirs with it.
///
/// Unless the app lists them (the desktop a sidebar of them), the phone's:
/// with a multisig selected, its signers in this wallet, whose balances
/// decide whether one of them can pay to approve, execute or cancel.
final shownBalanceAccountIdsProvider = Provider<Set<String>>((ref) {
  final active = ref.watch(activeAccountProvider).value?.account;
  if (active is! MultisigAccount) return const {};
  final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
  return {for (final signer in localSignersForMultisig(active, accounts)) signer.accountId};
});
