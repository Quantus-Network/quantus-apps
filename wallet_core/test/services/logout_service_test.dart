import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/notification_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/pending_transaction_polling_service.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';

import '../fakes.dart';

Future<void> _turnNotificationsOff(ProviderContainer container) => container
    .read(notificationConfigProvider.notifier)
    .updateConfig(container.read(notificationConfigProvider).copyWith(enabled: false));

NotificationData _reminderIn(Duration delay) => NotificationData(
  id: 'reminder',
  accountId: 'account',
  type: NotificationType.reminder,
  intent: NotificationIntent.reversibleTransactions,
  source: NotificationSource.local,
  title: 'Reminder',
  message: 'A reversible send is about to run',
  accountName: 'Account',
  timestamp: DateTime.now(),
  scheduledTime: DateTime.now().add(delay),
);

NotificationData _shown(String id) => NotificationData(
  id: id,
  accountId: 'account',
  type: NotificationType.success,
  intent: NotificationIntent.sentTokens,
  source: NotificationSource.local,
  title: 'Sent',
  message: 'From Account',
  accountName: 'Account',
  timestamp: DateTime.now(),
);

/// The indexer: it holds [holds], and each search waits for [held] when set.
class _Indexer extends Fake implements ChainHistoryService {
  TransactionEvent? holds;
  Completer<void>? held;
  int reads = 0;

  @override
  Future<TransactionEvent?> searchByExtrinsicHash({required String extrinsicHash, required bool isReversible}) async {
    reads++;
    await held?.future;
    return holds;
  }
}

typedef _Watched = ({WalletTestBed bed, _Indexer indexer, ProviderContainer container});

PendingTransactionEvent _pendingSend(String id) => PendingTransactionEvent(
  tempId: id,
  from: 'qzFrom',
  to: 'qzTo',
  amount: BigInt.one,
  fee: BigInt.zero,
  timestamp: DateTime(2026),
  blockNumber: 1,
);

/// Submits a send through the real submission service, which then watches
/// the indexer for it.
Future<void> _submit(ProviderContainer container, {String id = 'tx-1'}) async {
  final pending = _pendingSend(id);
  container.read(pendingTransactionsProvider.notifier).add(pending);
  await container
      .read(transactionSubmissionServiceProvider)
      .submitAndTrackTransaction(() async => Uint8List.fromList([1]), pending);
}

ReversibleTransferEvent _reversibleFound() => ReversibleTransferEvent(
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

TransferEvent _transferFound() => TransferEvent(
  id: 'found',
  from: 'qzFrom',
  to: 'qzTo',
  amount: BigInt.one,
  timestamp: DateTime(2026),
  fee: BigInt.zero,
  blockNumber: 2,
  blockHash: '0xblock',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a reset brings back the default notification settings', (tester) async {
    final container = ProviderContainer(overrides: WalletTestBed().overrides);
    await _turnNotificationsOff(container);

    await container.read(logoutServiceProvider).logout();
    await tester.pump();

    expect(container.read(notificationConfigProvider).enabled, isTrue);
    container.dispose();
  });

  testWidgets('a wipe that fails leaves the notification settings as they were', (tester) async {
    final bed = WalletTestBed()..substrate.logoutError = StateError('the wipe failed');
    final container = ProviderContainer(overrides: bed.overrides);
    await _turnNotificationsOff(container);

    await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);
    await tester.pump();

    expect(container.read(notificationConfigProvider).enabled, isFalse);
    container.dispose();
  });

  testWidgets('with a setting changed, a reminder scheduled before a reset does not fire after it', (tester) async {
    final container = ProviderContainer(overrides: WalletTestBed().overrides);
    // Only a config that differs from the defaults rebuilds the notifier.
    await container
        .read(notificationConfigProvider.notifier)
        .updateConfig(container.read(notificationConfigProvider).copyWith(sound: false));
    final notifications = container.read(notificationProvider.notifier);
    await tester.pump();
    await notifications.addNotification(_reminderIn(const Duration(hours: 1)));
    expect(notifications.getScheduledNotificationIds(), ['reminder']);

    await container.read(logoutServiceProvider).logout();
    // The next session's first use replaces the notifier.
    container.read(notificationProvider);
    await tester.pump();
    await tester.pump(const Duration(hours: 2));

    expect(tester.takeException(), isNull);
    expect(container.read(notificationProvider), isEmpty);
    container.dispose();
  });

  group('with the default notification settings', () {
    testWidgets('a reminder scheduled before a reset does not fire after it', (tester) async {
      final container = ProviderContainer(overrides: WalletTestBed().overrides);
      final notifications = container.read(notificationProvider.notifier);
      await tester.pump();
      await notifications.addNotification(_reminderIn(const Duration(hours: 1)));

      await container.read(logoutServiceProvider).logout();
      await tester.pump(const Duration(hours: 2));

      expect(tester.takeException(), isNull);
      expect(container.read(notificationProvider), isEmpty);
      await tester.pump();
      container.dispose();
    });

    testWidgets("a reset empties the old wallet's notifications", (tester) async {
      final container = ProviderContainer(overrides: WalletTestBed().overrides);
      container.read(notificationProvider);
      await tester.pump();
      await container.read(notificationProvider.notifier).addNotification(_shown('old'));
      await tester.pump();
      expect(container.read(notificationProvider), hasLength(1));

      await container.read(logoutServiceProvider).logout();

      expect(container.read(notificationProvider), isEmpty);
      await tester.pump();
      container.dispose();
    });

    testWidgets('the next notification saves only itself, and shows', (tester) async {
      final container = ProviderContainer(overrides: WalletTestBed().overrides);
      container.read(notificationProvider);
      await tester.pump();
      await container.read(notificationProvider.notifier).addNotification(_shown('old'));

      await container.read(logoutServiceProvider).logout();
      container.read(notificationProvider);
      await tester.pump();
      await container.read(notificationProvider.notifier).addNotification(_shown('new'));
      await tester.pump();

      expect(container.read(notificationProvider).map((n) => n.id), ['new']);
      final saved = (await SharedPreferences.getInstance()).getStringList(notificationsStorageKey)!;
      expect(saved.map((json) => jsonDecode(json)['id']), ['new']);
      container.dispose();
    });

    testWidgets('a wipe that fails leaves the list and the scheduled reminder in place', (tester) async {
      final bed = WalletTestBed()..substrate.logoutError = StateError('the wipe failed');
      final container = ProviderContainer(overrides: bed.overrides);
      final notifications = container.read(notificationProvider.notifier);
      await tester.pump();
      await notifications.addNotification(_shown('old'));
      await notifications.addNotification(_reminderIn(const Duration(hours: 1)));

      await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);

      expect(container.read(notificationProvider).map((n) => n.id), ['old']);
      expect(container.read(notificationProvider.notifier).getScheduledNotificationIds(), ['reminder']);
      container.dispose();
    });
  });

  group("the system's notifications", () {
    testWidgets('a reset cancels them', (tester) async {
      final bed = WalletTestBed();
      final container = ProviderContainer(overrides: bed.overrides);

      await container.read(logoutServiceProvider).logout();
      await tester.pump();

      expect(bed.localNotifications.cancelAllCalls, 1);
      container.dispose();
    });

    testWidgets('a wipe that fails leaves them', (tester) async {
      final bed = WalletTestBed()..substrate.logoutError = StateError('the wipe failed');
      final container = ProviderContainer(overrides: bed.overrides);

      await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);

      expect(bed.localNotifications.cancelAllCalls, 0);
      container.dispose();
    });

    testWidgets('when they cannot be cancelled, the reset still finishes and it is reported', (tester) async {
      final bed = WalletTestBed();
      bed.localNotifications.cancelAllError = StateError('the system refused');
      final container = ProviderContainer(overrides: bed.overrides);
      container
          .read(pendingTransactionsProvider.notifier)
          .add(
            PendingTransactionEvent(
              tempId: 'tx-1',
              from: 'qzFrom',
              to: 'qzTo',
              amount: BigInt.one,
              fee: BigInt.zero,
              timestamp: DateTime(2026),
            ),
          );

      await container.read(logoutServiceProvider).logout();
      await tester.pump();

      expect(bed.telemetry.errors, ['logout_cancel_notifications_failed']);
      // What comes after it in the reset still ran.
      expect(container.read(pendingTransactionsProvider), isEmpty);
      container.dispose();
    });
  });

  group('a send under way at a reset', () {
    /// A wallet with nothing sent yet, over the indexer.
    Future<_Watched> wallet(WidgetTester tester, {Completer<void>? held}) async {
      final bed = WalletTestBed();
      final indexer = _Indexer()..held = held;
      final container = ProviderContainer(
        overrides: [...bed.overrides, chainHistoryServiceProvider.overrideWithValue(indexer)],
      );
      container.read(notificationProvider);
      await tester.pump();
      return (bed: bed, indexer: indexer, container: container);
    }

    /// A wallet that has just submitted a send, which the indexer does not
    /// hold yet. A first search has run, or is held by [held].
    Future<_Watched> watching(WidgetTester tester, {Completer<void>? held}) async {
      final watched = await wallet(tester, held: held);
      await _submit(watched.container);
      await tester.pump();
      return watched;
    }

    Future<String> transfer(_Watched watched) => watched.container
        .read(transactionSubmissionServiceProvider)
        .balanceTransfer(
          makeAccount(1),
          call: FakeBalancesService().getBalanceTransferCall('qzTo', BigInt.one),
          targetAddress: 'qzTo',
          amount: BigInt.one,
          fee: BigInt.zero,
        );

    void expectNothingNotified(_Watched watched) {
      expect(watched.bed.localNotifications.shown, isEmpty);
      expect(watched.container.read(notificationProvider), isEmpty);
      expect(watched.container.read(notificationProvider.notifier).getScheduledNotificationIds(), isEmpty);
    }

    for (final (kind, found) in [('reversible', _reversibleFound), ('plain', _transferFound)]) {
      testWidgets('a $kind send found by the next poll after it notifies nothing', (tester) async {
        final watched = await watching(tester);

        await watched.container.read(logoutServiceProvider).logout();
        await tester.pump();
        final readsAtTheReset = watched.indexer.reads;
        watched.indexer.holds = found();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(watched.indexer.reads, readsAtTheReset);
        expectNothingNotified(watched);
        await tester.pump();
        watched.container.dispose();
      });

      testWidgets('a $kind send whose search was in flight notifies nothing', (tester) async {
        final held = Completer<void>();
        final watched = await watching(tester, held: held);

        await watched.container.read(logoutServiceProvider).logout();
        await tester.pump();
        watched.indexer.holds = found();
        held.complete();
        await tester.pump();

        expectNothingNotified(watched);
        await tester.pump();
        watched.container.dispose();
      });

      testWidgets('a $kind send whose submission answers after it is not watched and notifies nothing', (tester) async {
        final watched = await wallet(tester);
        watched.indexer.holds = found();
        final accepted = Completer<Uint8List>();
        final pending = _pendingSend('tx-1');
        watched.container.read(pendingTransactionsProvider.notifier).add(pending);
        final submission = watched.container
            .read(transactionSubmissionServiceProvider)
            .submitAndTrackTransaction(() => accepted.future, pending);

        await watched.container.read(logoutServiceProvider).logout();
        await tester.pump();
        expect(watched.bed.localNotifications.cancelAllCalls, 1);
        accepted.complete(Uint8List.fromList([1]));
        // It did reach the network, so its hash is still the answer.
        expect(await submission, '0x01');
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(watched.indexer.reads, 0);
        expect(watched.container.read(pendingTransactionsProvider), isEmpty);
        expectNothingNotified(watched);
        final saved = (await SharedPreferences.getInstance()).getStringList(notificationsStorageKey);
        expect(saved, isNull);
        await tester.pump();
        watched.container.dispose();
      });
    }

    group('while the wipe is running', () {
      List<String>? savedNotifications(SharedPreferences prefs) => prefs.getStringList(notificationsStorageKey);

      testWidgets('a search that answers saves and notifies nothing', (tester) async {
        final held = Completer<void>();
        final watched = await watching(tester, held: held);
        await watched.container.read(notificationProvider.notifier).addNotification(_shown('old'));
        final wipe = watched.bed.substrate.holdWipe = Completer<void>();
        final shownBefore = watched.bed.localNotifications.shown.length;

        final logout = watched.container.read(logoutServiceProvider).logout();
        await tester.pump();
        watched.indexer.holds = _transferFound();
        held.complete();
        await tester.pump();
        await tester.pump();

        expect(savedNotifications(await SharedPreferences.getInstance()), isNull);
        expect(watched.bed.localNotifications.shown, hasLength(shownBefore));
        wipe.complete();
        await logout;
        await tester.pump();
        expect(savedNotifications(await SharedPreferences.getInstance()), isNull);
        watched.container.dispose();
      });

      testWidgets('a search that starts then and answers after it notifies nothing', (tester) async {
        final watched = await watching(tester);
        final wipe = watched.bed.substrate.holdWipe = Completer<void>();

        final logout = watched.container.read(logoutServiceProvider).logout();
        await tester.pump();
        // The next tick runs during the wipe, and its search is held.
        final answer = watched.indexer.held = Completer<void>();
        final readsBefore = watched.indexer.reads;
        await tester.pump(const Duration(seconds: 6));
        expect(watched.indexer.reads, greaterThan(readsBefore));
        wipe.complete();
        await logout;
        await tester.pump();
        watched.indexer.holds = _transferFound();
        answer.complete();
        await tester.pump();
        await tester.pump();

        expectNothingNotified(watched);
        expect(savedNotifications(await SharedPreferences.getInstance()), isNull);
        watched.container.dispose();
      });

      testWidgets('a broadcast that answers is not tracked', (tester) async {
        final watched = await wallet(tester);
        watched.indexer.holds = _transferFound();
        final accepted = Completer<Uint8List>();
        final pending = _pendingSend('tx-1');
        watched.container.read(pendingTransactionsProvider.notifier).add(pending);
        final submission = watched.container
            .read(transactionSubmissionServiceProvider)
            .submitAndTrackTransaction(() => accepted.future, pending);
        final wipe = watched.bed.substrate.holdWipe = Completer<void>();

        final logout = watched.container.read(logoutServiceProvider).logout();
        await tester.pump();
        accepted.complete(Uint8List.fromList([1]));
        expect(await submission, '0x01');
        await tester.pump();
        wipe.complete();
        await logout;
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(watched.indexer.reads, 0);
        expect(watched.container.read(pendingTransactionsProvider), isEmpty);
        expectNothingNotified(watched);
        await tester.pump();
        watched.container.dispose();
      });
    });

    group('after a wipe that failed', () {
      testWidgets('polling goes on, and a send found later still notifies', (tester) async {
        final watched = await watching(tester);
        watched.bed.substrate.logoutError = StateError('the wipe failed');

        await expectLater(watched.container.read(logoutServiceProvider).logout(), throwsStateError);
        // A reversible send is the one that reaches the system's notifications.
        watched.indexer.holds = _reversibleFound();
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(watched.bed.localNotifications.shown, hasLength(1));
        watched.container.dispose();
      });

      testWidgets('a broadcast that answers afterwards is still tracked', (tester) async {
        final watched = await wallet(tester);
        final accepted = Completer<Uint8List>();
        final pending = _pendingSend('tx-1');
        watched.container.read(pendingTransactionsProvider.notifier).add(pending);
        final submission = watched.container
            .read(transactionSubmissionServiceProvider)
            .submitAndTrackTransaction(() => accepted.future, pending);
        watched.bed.substrate.logoutError = StateError('the wipe failed');

        await expectLater(watched.container.read(logoutServiceProvider).logout(), throwsStateError);
        accepted.complete(Uint8List.fromList([1]));
        expect(await submission, '0x01');
        await tester.pump();

        expect(watched.indexer.reads, 1);
        expect(watched.container.read(pendingTransactionsProvider), hasLength(1));
        watched.container.read(pendingTransactionPollingServiceProvider).stopAll();
        watched.container.dispose();
      });
    });

    testWidgets('a transfer still being signed is neither broadcast nor listed', (tester) async {
      final watched = await wallet(tester);
      final signing = Completer<void>();
      watched.bed.substrate.holdSigning = signing;
      final refused = expectLater(transfer(watched), throwsStateError);

      await watched.container.read(logoutServiceProvider).logout();
      await tester.pump();
      signing.complete();
      await refused;
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(watched.bed.substrate.broadcast, isEmpty);
      expect(watched.container.read(pendingTransactionsProvider), isEmpty);
      expect(watched.indexer.reads, 0);
      expectNothingNotified(watched);
      await tester.pump();
      watched.container.dispose();
    });

    testWidgets('without a reset, a signed transfer is broadcast and watched', (tester) async {
      final watched = await wallet(tester);

      expect(await transfer(watched), '0x01');
      await tester.pump();

      expect(watched.bed.substrate.broadcast, hasLength(1));
      expect(watched.container.read(pendingTransactionsProvider), hasLength(1));
      expect(watched.indexer.reads, 1);
      watched.container.dispose();
    });

    testWidgets('a transfer started after the reset is broadcast and watched', (tester) async {
      final watched = await wallet(tester);
      await watched.container.read(logoutServiceProvider).logout();
      watched.container.read(notificationProvider);
      await tester.pump();

      expect(await transfer(watched), '0x01');
      await tester.pump();

      expect(watched.bed.substrate.broadcast, hasLength(1));
      expect(watched.container.read(pendingTransactionsProvider), hasLength(1));
      expect(watched.indexer.reads, 1);
      watched.container.dispose();
    });

    testWidgets('without a reset, a send found by a later poll still notifies', (tester) async {
      final watched = await watching(tester);

      watched.indexer.holds = _reversibleFound();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(watched.bed.localNotifications.shown, hasLength(1));
      expect(watched.container.read(notificationProvider.notifier).getScheduledNotificationIds(), hasLength(1));
      watched.container.dispose();
    });

    testWidgets('a new send after the reset is watched and notifies', (tester) async {
      final watched = await watching(tester);
      await watched.container.read(logoutServiceProvider).logout();
      watched.container.read(notificationProvider);
      await tester.pump();

      await _submit(watched.container, id: 'tx-after');
      await tester.pump();
      watched.indexer.holds = _reversibleFound();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(watched.bed.localNotifications.shown, hasLength(1));
      watched.container.dispose();
    });
  });
}
