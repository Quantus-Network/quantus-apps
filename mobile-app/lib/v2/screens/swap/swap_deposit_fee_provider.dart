import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';

/// Chain fee for sending [amount] QTC from the account into a deposit address.
/// The recipient barely moves the fee, so the account's own address stands in
/// until the live quote names the deposit address.
final swapDepositFeeProvider = FutureProvider.autoDispose.family<BigInt, (Account, BigInt)>((ref, args) async {
  final (account, amount) = args;
  try {
    return (await RegularSendStrategy(
      account: account,
    ).fetchFee(ref.read, recipient: account.accountId, amount: amount)).networkFee;
  } catch (e) {
    quantusPrint('Swap deposit fee failed: $e');
    rethrow;
  }
}, retry: (_, _) => null);
