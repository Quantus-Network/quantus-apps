import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances;
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';

// Local provider for existential deposit toggle in send screen
final existentialDepositToggleProvider = StateProvider<bool>((ref) => true);

/// True while a send flow is on the navigation stack. Only one send flow can
/// be active at a time; incoming intents that would start or interrupt a send
/// are ignored while this is set. Only mutated by [startSendFlow].
final sendFlowActiveProvider = StateProvider<bool>((_) => false);

/// Single entry point for send flows: refuses to start a second flow, starts a
/// fresh Keystone signing session (a QR cached by an earlier flow may carry a
/// stale nonce), and clears the in-flight flag when [screen]'s route leaves
/// the stack — by pop, replacement, or removal.
Future<void> startSendFlow(BuildContext context, {required Widget screen}) async {
  final container = ProviderScope.containerOf(context);
  final sendFlow = container.read(sendFlowActiveProvider.notifier);
  if (sendFlow.state) {
    quantusPrint('startSendFlow ignored: a send flow is already active');
    return;
  }
  container.read(keystoneSignCacheProvider.notifier).startNewSendSession();
  sendFlow.state = true;
  try {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
  } finally {
    sendFlow.state = false;
  }
}

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
