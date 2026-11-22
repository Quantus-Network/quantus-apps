import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_deposit_fee_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

import '../fakes.dart';

/// Records what a transfer call was built for.
class _Balances extends FakeBalancesService {
  final transfers = <(String, BigInt)>[];

  @override
  Balances getBalanceTransferCall(String targetAddress, BigInt amount) {
    transfers.add((targetAddress, amount));
    return super.getBalanceTransferCall(targetAddress, amount);
  }
}

/// The chain unable to price a call.
class _SubstrateDown extends FakeSubstrateService {
  @override
  Future<ExtrinsicFeeData> getFeeForCall(Account account, RuntimeCall call) async => throw StateError('chain down');
}

void main() {
  final account = makeAccount(1);
  final amount = BigInt.from(10).pow(AppConstants.decimals) * BigInt.from(250);

  ProviderContainer containerWith(SubstrateService substrate, _Balances balances) {
    final container = ProviderContainer(
      overrides: [
        substrateServiceProvider.overrideWithValue(substrate),
        balancesServiceProvider.overrideWithValue(balances),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    "the deposit's fee is the chain's for sending the amount from the account, its own address standing in",
    () async {
      final substrate = FakeSubstrateService(fee: BigInt.from(1200000000));
      final balances = _Balances();
      final container = containerWith(substrate, balances);
      final key = swapDepositFeeProvider((account, amount));
      final kept = container.listen(key, (_, _) {});
      addTearDown(kept.close);

      expect(await container.read(key.future), BigInt.from(1200000000));
      expect(balances.transfers, [(account.accountId, amount)]);
      expect(substrate.lastFeeAccount, account);
      expect(substrate.feeCalls, 1);
    },
  );

  test('a fee the chain cannot give is an error, asked for once', () async {
    final balances = _Balances();
    final container = containerWith(_SubstrateDown(), balances);
    final key = swapDepositFeeProvider((account, amount));
    final kept = container.listen(key, (_, _) {}, onError: (_, _) {});
    addTearDown(kept.close);

    await expectLater(container.read(key.future), throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(container.read(key).hasError, isTrue);
    expect(balances.transfers, hasLength(1));
  });
}
