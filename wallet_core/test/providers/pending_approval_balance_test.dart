import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("an approval on its way holds back its fee from the approver's spendable balance, and no one else's", () async {
    final container = ProviderContainer(
      overrides: [balanceProviderFamily.overrideWith((ref, accountId) async => BigInt.from(100))],
    );
    addTearDown(container.dispose);
    for (final id in ['qzApprover', 'qzOther', 'qzTeam']) {
      container.listen(effectiveBalanceProviderFamily(id), (_, _) {});
    }
    await pumpEventQueue();

    container
        .read(pendingMultisigApprovalsProvider.notifier)
        .add(
          PendingMultisigApprovalEvent.create(
            multisigAddress: 'qzTeam',
            proposalId: 1,
            approverId: 'qzApprover',
            recipient: 'qzOther',
            amount: BigInt.from(50),
            fee: BigInt.from(7),
          ),
        );
    await pumpEventQueue();

    expect(container.read(effectiveBalanceProviderFamily('qzApprover')).value, BigInt.from(93));
    expect(container.read(effectiveBalanceProviderFamily('qzOther')).value, BigInt.from(100));
    expect(container.read(effectiveBalanceProviderFamily('qzTeam')).value, BigInt.from(100));
  });
}
