import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/notification_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';

import '../fakes.dart';

/// An indexer whose every search waits for the test to answer it.
class _Indexer extends Fake implements ChainHistoryService {
  final searches = <Completer<TransactionEvent?>>[];

  @override
  Future<TransactionEvent?> searchByExtrinsicHash({required String extrinsicHash, required bool isReversible}) {
    final search = Completer<TransactionEvent?>();
    searches.add(search);
    return search.future;
  }

  @override
  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    AccountEventCursor? otherAfter,
    AccountEventCursor? scheduledAfter,
    required TransactionFilter filter,
  }) async => SortedTransactionsList.empty;
}

TransferEvent _plain() => TransferEvent(
  id: 'found',
  from: 'qzFrom',
  to: 'qzTo',
  amount: BigInt.one,
  timestamp: DateTime(2026),
  fee: BigInt.zero,
  blockNumber: 2,
  blockHash: '0xblock',
);

ReversibleTransferEvent _reversible() => ReversibleTransferEvent(
  id: 'found',
  from: 'qzFrom',
  to: 'qzTo',
  amount: BigInt.one,
  timestamp: DateTime(2026),
  txId: 'tx',
  status: ReversibleTransferStatus.SCHEDULED,
  scheduledAt: DateTime.now().add(const Duration(hours: 3)),
  blockNumber: 2,
  blockHash: '0xblock',
);

typedef _Sending = ({WalletTestBed bed, _Indexer indexer, ProviderContainer container});

const _tick = Duration(seconds: 5);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A send just broadcast, its first search waiting for an answer.
  Future<_Sending> sending(WidgetTester tester) async {
    final bed = WalletTestBed();
    final indexer = _Indexer();
    final container = ProviderContainer(
      overrides: [...bed.overrides, chainHistoryServiceProvider.overrideWithValue(indexer)],
    );
    container.read(notificationProvider);
    await tester.pump();
    final pending = PendingTransactionEvent(
      tempId: 'tx-1',
      from: 'qzFrom',
      to: 'qzTo',
      amount: BigInt.one,
      fee: BigInt.zero,
      timestamp: DateTime(2026),
      blockNumber: 1,
    );
    container.read(pendingTransactionsProvider.notifier).add(pending);
    await container
        .read(transactionSubmissionServiceProvider)
        .submitAndTrackTransaction(() async => Uint8List.fromList([1]), pending);
    await tester.pump();
    return (bed: bed, indexer: indexer, container: container);
  }

  Future<void> answer(WidgetTester tester, Completer<TransactionEvent?> search, TransactionEvent? found) async {
    search.complete(found);
    await tester.pump();
    await tester.pump();
  }

  for (final (kind, found) in [('plain', _plain), ('reversible', _reversible)]) {
    /// A plain send is listed; a reversible one also goes to the system.
    int notifiedTimes(_Sending send) =>
        kind == 'plain' ? send.container.read(notificationProvider).length : send.bed.localNotifications.shown.length;

    testWidgets('a slow search of a $kind send blocks a second one, and it notifies once', (tester) async {
      final send = await sending(tester);

      await tester.pump(_tick * 3);
      expect(send.indexer.searches, hasLength(1));

      await answer(tester, send.indexer.searches.single, found());

      expect(notifiedTimes(send), 1);
      expect(send.container.read(pendingTransactionsProvider), isEmpty);
      await tester.pump(_tick * 2);
      expect(send.indexer.searches, hasLength(1));
      send.container.dispose();
    });

    testWidgets('a $kind send found on a later search notifies once', (tester) async {
      final send = await sending(tester);
      await answer(tester, send.indexer.searches.first, null);

      await tester.pump(_tick);
      expect(send.indexer.searches, hasLength(2));
      await answer(tester, send.indexer.searches.last, found());

      expect(notifiedTimes(send), 1);
      await tester.pump(_tick * 2);
      expect(send.indexer.searches, hasLength(2));
      send.container.dispose();
    });
  }

  testWidgets('a search that finds nothing frees the next tick to search again', (tester) async {
    final send = await sending(tester);

    await answer(tester, send.indexer.searches.single, null);
    await tester.pump(_tick);

    expect(send.indexer.searches, hasLength(2));
    send.container.dispose();
  });

  testWidgets('a search that fails frees the next tick to search again', (tester) async {
    final send = await sending(tester);

    send.indexer.searches.single.completeError(StateError('the indexer is down'));
    await tester.pump();
    await tester.pump(_tick);

    expect(send.indexer.searches, hasLength(2));
    send.container.dispose();
  });
}
