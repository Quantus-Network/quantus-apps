import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// Starts a send flow for [strategy]: a fresh Keystone signing session (a QR
/// cached by an earlier flow may carry a stale nonce), and the previous
/// flow's fee replaced with a first quote.
///
/// Called from the event that opens the flow, which is where the first quote
/// is asked for: a screen must not write a provider from its own lifecycle.
void beginSendFlow(ProviderReader read, SendStrategy strategy) {
  read(keystoneSignCacheProvider.notifier).startNewSendSession();
  read(sendFeeProvider.notifier).reset();
  final source = strategy.sourceAccountId;
  if (source != null) {
    strategy.requestFee(read, recipient: source, amount: SendStrategy.feeProbeAmount);
  }
}
