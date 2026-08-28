import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';

import '../fakes.dart';

void main() {
  final captured = makeAccount(1);
  final other = makeAccount(2);

  Future<WidgetRef> pumpRef(WidgetTester tester, {List<Override> overrides = const []}) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) {
            widgetRef = ref;
            return const SizedBox();
          },
        ),
      ),
    );
    return widgetRef;
  }

  testWidgets('stays bound to the captured account after the active account switches', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(other));
    final ref = await pumpRef(tester, overrides: [settingsServiceProvider.overrideWithValue(settings)]);
    final strategy = RegularSendStrategy(account: captured);

    ref.read(activeAccountProvider);
    await tester.pump();
    expect(ref.read(activeAccountProvider).value?.account.accountId, other.accountId);

    expect(strategy.sourceAccountId(ref), captured.accountId);
    expect(strategy.spendableBalanceProvider, effectiveMaxBalanceProviderFamily(captured.accountId));
  });

  testWidgets('validates against the captured account balance, not the active one', (tester) async {
    final existentialDeposit = balances.Constants().existentialDeposit;
    final capturedBalance = existentialDeposit * BigInt.from(100);
    final ref = await pumpRef(
      tester,
      overrides: [
        effectiveBalanceProviderFamily.overrideWith(
          (r, accountId) => AsyncValue.data(accountId == captured.accountId ? capturedBalance : BigInt.one),
        ),
      ],
    );
    final strategy = RegularSendStrategy(account: captured);

    expect(ref.read(strategy.spendableBalanceProvider).value, capturedBalance - existentialDeposit);
  });

  test('fee provider prices any amount locally from one probed dispatch weight', () async {
    final balancesService = FakeBalancesService();
    final container = ProviderContainer(overrides: [balancesServiceProvider.overrideWithValue(balancesService)]);
    addTearDown(container.dispose);
    final strategy = RegularSendStrategy(account: captured);
    final ten = strategy.feeProvider(recipient: other.accountId, amount: BigInt.from(10));
    final twenty = strategy.feeProvider(recipient: other.accountId, amount: BigInt.from(20));
    final subs = [ten, twenty].map((p) => container.listen(p, (_, _) {})).toList();

    expect(subs[0].read().isLoading, isTrue);
    await container.read(transferDispatchWeightProvider.future);

    expect(
      (subs[0].read().requireValue as RegularFee).networkFee,
      BigInt.from(10) + FakeBalancesService.dispatchWeight,
    );
    expect(
      (subs[1].read().requireValue as RegularFee).networkFee,
      BigInt.from(20) + FakeBalancesService.dispatchWeight,
    );
    expect(balancesService.weightProbes, 1);
  });

  testWidgets('submit hands the captured keystone account to the signing session after a switch', (tester) async {
    final keystone = makeAccount(3, accountType: AccountType.keystone);
    final settings = FakeSettingsService(activeAccount: RegularAccount(other));
    final ref = await pumpRef(tester, overrides: [settingsServiceProvider.overrideWithValue(settings)]);
    final strategy = RegularSendStrategy(account: keystone);

    ref.read(activeAccountProvider);
    await tester.pump();
    expect(ref.read(activeAccountProvider).value?.account.accountId, other.accountId);

    final outcome = await strategy.submit(
      ref,
      recipientAddress: other.accountId,
      recipientChecksum: 'checksum',
      amount: BigInt.from(1000),
      fee: RegularFee(networkFee: BigInt.from(10)),
      isPayMode: false,
    );

    expect(outcome, isA<SendNeedsHardwareSignature>());
    expect((outcome as SendNeedsHardwareSignature).session.account.accountId, keystone.accountId);
  });
}
