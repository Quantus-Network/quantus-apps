import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/shared/utils/polling_refresh_scope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('accountRefreshTargets', () {
    test('includes affected and active accounts without wallet-wide fan-out', () {
      final targets = accountRefreshTargets(affectedAccountIds: {'account-a', 'account-b'}, activeId: 'account-c');

      expect(targets, hasLength(3));
      expect(targets.map((ids) => ids.single).toSet(), {'account-a', 'account-b', 'account-c'});
    });

    test('deduplicates active account when already affected', () {
      final targets = accountRefreshTargets(affectedAccountIds: {'account-a'}, activeId: 'account-a');

      expect(targets, hasLength(1));
      expect(targets.single, ['account-a']);
    });
  });

  group('reconciliationAccountIds', () {
    test('scopes to active account and pending transaction parties', () {
      final pendingTx = PendingTransactionEvent(
        tempId: 'tx-1',
        from: 'sender',
        to: 'receiver',
        amount: BigInt.one,
        timestamp: DateTime(2024),
        transactionState: TransactionState.pending,
        isReversible: false,
        fee: BigInt.zero,
      );

      final ids = reconciliationAccountIds(activeId: 'active', pendingTxs: [pendingTx]);

      expect(ids, {'active', 'sender', 'receiver'});
    });

    test('does not include unrelated wallet accounts', () {
      final pendingTx = PendingTransactionEvent(
        tempId: 'tx-2',
        from: 'sender',
        to: 'receiver',
        amount: BigInt.one,
        timestamp: DateTime(2024),
        transactionState: TransactionState.pending,
        isReversible: false,
        fee: BigInt.zero,
      );

      final ids = reconciliationAccountIds(activeId: 'active', pendingTxs: [pendingTx]);

      expect(ids.contains('unrelated-account'), isFalse);
    });
  });
}
