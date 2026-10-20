import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

final swapTokensProvider = FutureProvider<List<SwapToken>>((ref) => ref.watch(swapServiceProvider).getFromTokens());

/// Chain fee for sending [amount] QTC into a deposit address. The recipient
/// barely moves the fee, so the account's own address stands in until the
/// live quote names the deposit address.
final swapDepositFeeProvider = FutureProvider.autoDispose.family<BigInt, (Account, BigInt)>((ref, args) async {
  final (account, amount) = args;
  final call = ref.read(balancesServiceProvider).getBalanceTransferCall(account.accountId, amount);
  return (await ref.read(substrateServiceProvider).getFeeForCall(account, call)).fee;
});

final swapSavedAddressesProvider = FutureProvider.autoDispose.family<List<String>, String>(
  (ref, network) => ref.watch(swapServiceProvider).getSavedAddresses(network),
);
