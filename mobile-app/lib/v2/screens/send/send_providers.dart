import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances;
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

// Local provider for existential deposit toggle in send screen
final existentialDepositToggleProvider = StateProvider<bool>((ref) => true);

// Provider that combines balance with existential deposit toggle
final effectiveMaxBalanceProvider = Provider<AsyncValue<BigInt>>((ref) {
  final existentialDeposit = balances.Constants().existentialDeposit;
  final balanceAsyncValue = ref.watch(balanceProvider);
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
