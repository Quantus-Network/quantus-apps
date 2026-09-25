import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances;
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

  testWidgets('stays bound to the captured account after the active account switches', (tester) async {
    final settings = FakeSettingsService(activeAccount: RegularAccount(other));
    final ref = await pumpRef(tester, overrides: [settingsServiceProvider.overrideWithValue(settings)]);
    final strategy = RegularSendStrategy(account: captured);

    ref.read(activeAccountProvider);
    await tester.pump();
    expect(ref.read(activeAccountProvider).value?.account.accountId, other.accountId);

    expect(strategy.sourceAccountId, captured.accountId);
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

  testWidgets('requestFee asks the chain for the captured account and publishes the fee', (tester) async {
    final substrate = FakeSubstrateService(fee: BigInt.from(1000000000));
    final ref = await pumpRef(
      tester,
      overrides: [
        substrateServiceProvider.overrideWithValue(substrate),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    final strategy = RegularSendStrategy(account: captured);
    final feeProvider = strategy.feeProvider(recipient: other.accountId, amount: BigInt.from(10));
    expect(ref.read(feeProvider).fee, isNull);

    strategy.requestFee(ref.read, recipient: other.accountId, amount: BigInt.from(10));
    await tester.pump();

    expect(substrate.lastFeeAccount?.accountId, captured.accountId);
    expect(isTransferAll(substrate.lastFeeCall!, keepAlive: true), isFalse);
    final fee = ref.read(feeProvider);
    expect((fee.fee as RegularFee).networkFee, BigInt.from(1000000000));
    expect(fee.settled, isTrue);
    expect(strategy.feeApplies(fee.fee!, amount: BigInt.from(10), sendAll: false), isTrue);
    expect(strategy.feeApplies(fee.fee!, amount: BigInt.from(11), sendAll: false), isFalse);
    expect(strategy.feeApplies(fee.fee!, amount: BigInt.from(10), sendAll: true), isFalse);
  });

  testWidgets('a max send prices transfer_all that keeps the existential deposit', (tester) async {
    final substrate = FakeSubstrateService(fee: BigInt.from(7));
    final ref = await pumpRef(
      tester,
      overrides: [
        substrateServiceProvider.overrideWithValue(substrate),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    final strategy = RegularSendStrategy(account: captured);

    strategy.requestFee(ref.read, recipient: other.accountId, amount: BigInt.from(10), sendAll: true, immediate: true);
    await tester.pump();

    expect(isTransferAll(substrate.lastFeeCall!, keepAlive: true), isTrue);
    final fee = ref.read(strategy.feeProvider(recipient: other.accountId, amount: BigInt.from(10))).fee as RegularFee;
    expect(fee.sendAll, isTrue);
    expect(fee.networkFee, BigInt.from(7));
    expect(strategy.feeApplies(fee, amount: BigInt.from(999), sendAll: true), isTrue);
  });

  testWidgets('a max send hands transfer_all to the keystone signing session', (tester) async {
    final keystone = makeAccount(3, accountType: AccountType.keystone);
    final ref = await pumpRef(
      tester,
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(keystone))),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    final strategy = RegularSendStrategy(account: keystone);

    final outcome = await strategy.submit(
      ref,
      recipientAddress: other.accountId,
      recipientChecksum: 'checksum',
      amount: BigInt.from(1000),
      fee: RegularFee(networkFee: BigInt.from(10), sendAll: true),
      isPayMode: false,
      sendAll: true,
    );

    final session = (outcome as SendNeedsHardwareSignature).session;
    expect(isTransferAll(session.buildCall(), keepAlive: true), isTrue);
  });

  testWidgets('the signed call follows the send mode, not the fee that happens to be retained', (tester) async {
    final keystone = makeAccount(3, accountType: AccountType.keystone);
    final ref = await pumpRef(
      tester,
      overrides: [
        settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(keystone))),
        balancesServiceProvider.overrideWithValue(FakeBalancesService()),
      ],
    );
    final strategy = RegularSendStrategy(account: keystone);
    final staleMaxFee = RegularFee(networkFee: BigInt.from(10), sendAll: true);

    final outcome = await strategy.submit(
      ref,
      recipientAddress: other.accountId,
      recipientChecksum: 'checksum',
      amount: BigInt.from(1000),
      fee: staleMaxFee,
      isPayMode: false,
    );
    expect(isTransferAll((outcome as SendNeedsHardwareSignature).session.buildCall(), keepAlive: true), isFalse);

    await expectLater(
      strategy.submit(
        ref,
        recipientAddress: other.accountId,
        recipientChecksum: 'checksum',
        amount: BigInt.from(1000),
        fee: RegularFee(networkFee: BigInt.from(10), amount: BigInt.from(1000)),
        isPayMode: false,
        sendAll: true,
      ),
      throwsStateError,
    );
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
