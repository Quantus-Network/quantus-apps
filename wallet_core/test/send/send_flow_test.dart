import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/send/send_fee_notifier.dart';
import 'package:wallet_core/send/send_flow.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/utils/provider_reader.dart';

/// A send that keeps the quotes it was asked for.
class _Strategy extends Fake implements SendStrategy {
  _Strategy(this.sourceAccountId);

  @override
  final String? sourceAccountId;

  /// Each quote's recipient and amount.
  final quotes = <(String, BigInt)>[];

  @override
  void requestFee(
    ProviderReader read, {
    required String recipient,
    required BigInt amount,
    bool sendAll = false,
    bool immediate = false,
  }) => quotes.add((recipient, amount));
}

class _CountingSignCache extends KeystoneSignCacheNotifier {
  int sessions = 0;

  @override
  void startNewSendSession() {
    sessions++;
    super.startNewSendSession();
  }
}

void main() {
  late _CountingSignCache signCache;
  late ProviderContainer container;

  setUp(() {
    signCache = _CountingSignCache();
    container = ProviderContainer(overrides: [keystoneSignCacheProvider.overrideWith((ref) => signCache)]);
    addTearDown(container.dispose);
  });

  test('drops the fee of the flow before and asks for a first quote from the source account', () async {
    container.read(sendFeeProvider.notifier).request(() async => RegularFee(networkFee: BigInt.from(7)));
    await pumpEventQueue();
    expect(container.read(sendFeeProvider).fee, isNotNull);
    final strategy = _Strategy('qzSource');

    beginSendFlow(container.read, strategy);

    expect(container.read(sendFeeProvider), const SendFeeState());
    expect(strategy.quotes, [('qzSource', SendStrategy.feeProbeAmount)]);
  });

  test('starts a new Keystone signing session, so a payload cached by the flow before is not served', () {
    beginSendFlow(container.read, _Strategy('qzSource'));

    expect(signCache.sessions, 1);
  });

  test('asks for no quote when the send has no source account to price it from', () {
    final strategy = _Strategy(null);

    beginSendFlow(container.read, strategy);

    expect(strategy.quotes, isEmpty);
  });
}
