import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances;
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

// Local provider for existential deposit toggle in send screen
final existentialDepositToggleProvider = StateProvider<bool>((ref) => true);

/// Number of send-flow root screens (select recipient / input amount) currently
/// on the navigation stack. While this is positive a send is in flight and
/// incoming intents must not interrupt it (e.g. a proposal-notification tap
/// switching the active account mid-send).
final sendFlowActiveProvider = StateProvider<int>((_) => 0);

/// Max sendable balance for [accountId]: the effective balance (chain balance
/// minus pending outgoing) with the existential deposit toggle applied. Send
/// strategies bind to the source account captured at flow start so a mid-flow
/// account switch cannot change the balance being validated against.
final effectiveMaxBalanceProviderFamily = Provider.family<AsyncValue<BigInt>, String>((ref, accountId) {
  final existentialDeposit = balances.Constants().existentialDeposit;
  final balanceAsyncValue = ref.watch(effectiveBalanceProviderFamily(accountId));
  final includeExistentialDeposit = ref.watch(existentialDepositToggleProvider);

  return balanceAsyncValue.when(
    data: (balance) {
      if (includeExistentialDeposit) {
        return AsyncValue.data(balance > existentialDeposit ? balance - existentialDeposit : BigInt.zero);
      } else {
        return AsyncValue.data(balance);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});
