import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/models/pending_multisig_creation_record.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/notification_provider.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';
import 'package:wallet_core/services/multisig_proposal_polling_service.dart';
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

  int proposalReads = 0;

  @override
  Future<MultisigProposalCreatedEvent?> searchProposalCreatedByExtrinsicHash({required String extrinsicHash}) async {
    proposalReads++;
    return null;
  }
}

/// The chain's answer to a proposal, held until the test gives it.
class _Multisigs extends Fake implements MultisigService {
  final accepted = Completer<Uint8List>();

  @override
  Future<Uint8List> propose({
    required MultisigAccount msig,
    required Account signer,
    required String recipient,
    required BigInt amount,
    required int expiryBlock,
  }) => accepted.future;
}

/// Whether the indexer knows a multisig: [indexed], or what [held] completes
/// with while it is set.
class _Creations extends Fake implements MultisigService {
  Completer<bool>? held;
  bool indexed = false;

  @override
  Future<bool> isMultisigIndexed(String multisigAddress) async => await held?.future ?? indexed;
}

typedef _Creating = ({
  WalletTestBed bed,
  _Creations chain,
  MultisigCreationPollingService poller,
  ProviderContainer container,
});

final _oldMultisig = MultisigAccount(
  name: 'Old multisig',
  accountId: 'qzOldMultisig',
  signers: const ['qzA', 'qzB'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzA',
  creator: 'qzA',
);

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

  group('a push being resolved at a reset', () {
    Future<(WalletTestBed, ProviderContainer)> wallet(WidgetTester tester) async {
      final bed = WalletTestBed();
      final container = ProviderContainer(overrides: bed.overrides);
      container.read(notificationProvider);
      await tester.pump();
      return (bed, container);
    }

    Future<void> expectNothingAdded(ProviderContainer container) async {
      expect(container.read(notificationProvider), isEmpty);
      expect(container.read(notificationProvider.notifier).getScheduledNotificationIds(), isEmpty);
      expect((await SharedPreferences.getInstance()).getStringList(notificationsStorageKey), isNull);
    }

    testWidgets('one answering during the wipe adds, saves and schedules nothing', (tester) async {
      final (bed, container) = await wallet(tester);
      final resolved = Completer<NotificationData?>();
      final pushed = addResolvedNotification(container.read, () => resolved.future);
      final wipe = bed.substrate.holdWipe = Completer<void>();

      final logout = container.read(logoutServiceProvider).logout();
      await tester.pump();
      resolved.complete(_reminderIn(const Duration(hours: 1)));
      await pushed;
      await tester.pump();

      await expectNothingAdded(container);
      wipe.complete();
      await logout;
      await tester.pump();
      await expectNothingAdded(container);
      await tester.pump();
      container.dispose();
    });

    testWidgets('one that starts during the wipe and answers after it adds nothing', (tester) async {
      final (bed, container) = await wallet(tester);
      final wipe = bed.substrate.holdWipe = Completer<void>();
      final logout = container.read(logoutServiceProvider).logout();
      await tester.pump();
      final resolved = Completer<NotificationData?>();
      final pushed = addResolvedNotification(container.read, () => resolved.future);

      wipe.complete();
      await logout;
      await tester.pump();
      resolved.complete(_reminderIn(const Duration(hours: 1)));
      await pushed;
      await tester.pump();

      await expectNothingAdded(container);
      await tester.pump();
      container.dispose();
    });

    testWidgets('one answering after a wipe that failed is added', (tester) async {
      final (bed, container) = await wallet(tester);
      final resolved = Completer<NotificationData?>();
      final pushed = addResolvedNotification(container.read, () => resolved.future);
      bed.substrate.logoutError = StateError('the wipe failed');

      await expectLater(container.read(logoutServiceProvider).logout(), throwsStateError);
      resolved.complete(_shown('kept'));
      await pushed;
      await tester.pump();

      expect(container.read(notificationProvider).map((n) => n.id), ['kept']);
      container.dispose();
    });

    testWidgets('with no reset, one is added', (tester) async {
      final (_, container) = await wallet(tester);

      await addResolvedNotification(container.read, () async => _shown('pushed'));
      await tester.pump();

      expect(container.read(notificationProvider).map((n) => n.id), ['pushed']);
      container.dispose();
    });

    testWidgets('one that resolves to nothing adds nothing', (tester) async {
      final (_, container) = await wallet(tester);

      await addResolvedNotification(container.read, () async => null);
      await tester.pump();

      await expectNothingAdded(container);
      container.dispose();
    });
  });

  group('a multisig being created at a reset', () {
    /// A wallet waiting for the indexer to answer about a multisig it created.
    Future<_Creating> creating(WidgetTester tester, {bool expired = false}) async {
      final bed = WalletTestBed();
      final chain = _Creations()..held = Completer<bool>();
      final container = ProviderContainer(
        overrides: [...bed.overrides, multisigServiceProvider.overrideWithValue(chain)],
      );
      final poller = container.read(multisigCreationPollingServiceProvider);
      await tester.pump();
      final submittedAt = expired ? DateTime.now().subtract(const Duration(hours: 1)) : DateTime.now();
      final record = PendingMultisigCreationRecord(
        draft: _oldMultisig,
        networkFee: BigInt.zero,
        submittedAt: submittedAt,
      );
      await container.read(pendingMultisigCreationsProvider.notifier).add(record.toEvent(), _oldMultisig);
      container.read(multisigAccountsProvider);
      await tester.pump();
      if (expired) {
        unawaited(poller.resumePendingCreations());
      } else {
        poller.startPolling(_oldMultisig);
      }
      await tester.pump();
      return (bed: bed, chain: chain, poller: poller, container: container);
    }

    void expectNothingOfIt(_Creating creation) {
      expect(creation.bed.settings.savedMultisigs, isEmpty);
      expect(creation.bed.pushRegistration.registeredAddresses, isEmpty);
      expect(creation.container.read(globalToastProvider), isNull);
    }

    testWidgets('one confirmed during the wipe is not saved, registers no push and shows no toast', (tester) async {
      final creation = await creating(tester);
      final wipe = creation.bed.substrate.holdWipe = Completer<void>();

      final logout = creation.container.read(logoutServiceProvider).logout();
      await tester.pump();
      creation.chain.held!.complete(true);
      await tester.pump();
      await tester.pump();

      expectNothingOfIt(creation);
      wipe.complete();
      await logout;
      await tester.pump();
      expectNothingOfIt(creation);
      creation.container.dispose();
    });

    testWidgets('one confirmed during the cancel of the system notifications is not saved either', (tester) async {
      final creation = await creating(tester);
      final cancel = creation.bed.localNotifications.holdCancel = Completer<void>();

      final logout = creation.container.read(logoutServiceProvider).logout();
      await tester.pump();
      expect(creation.bed.localNotifications.cancelAllCalls, 1);
      creation.chain.held!.complete(true);
      await tester.pump();
      await tester.pump();

      expectNothingOfIt(creation);
      cancel.complete();
      await logout;
      await tester.pump();
      creation.container.dispose();
    });

    testWidgets('the system notifications are cancelled only after the pending work is cleared', (tester) async {
      final creation = await creating(tester);
      final cancel = creation.bed.localNotifications.holdCancel = Completer<void>();

      final logout = creation.container.read(logoutServiceProvider).logout();
      await tester.pump();

      expect(creation.bed.localNotifications.cancelAllCalls, 1);
      expect(creation.container.read(pendingMultisigCreationsProvider), isEmpty);
      cancel.complete();
      creation.chain.held!.complete(false);
      await logout;
      await tester.pump();
      creation.container.dispose();
    });

    for (final indexed in [true, false]) {
      testWidgets('an expired one recovered during the reset (indexed: $indexed) saves and says nothing', (
        tester,
      ) async {
        final creation = await creating(tester, expired: true);
        final wipe = creation.bed.substrate.holdWipe = Completer<void>();

        final logout = creation.container.read(logoutServiceProvider).logout();
        await tester.pump();
        creation.chain.held!.complete(indexed);
        await tester.pump();
        await tester.pump();

        expectNothingOfIt(creation);
        wipe.complete();
        await logout;
        await tester.pump();
        creation.container.dispose();
      });
    }

    testWidgets('after a wipe that failed, one still confirms on the next poll', (tester) async {
      final creation = await creating(tester);
      final wipe = creation.bed.substrate.holdWipe = Completer<void>();
      creation.bed.substrate.logoutError = StateError('the wipe failed');

      final logout = creation.container.read(logoutServiceProvider).logout();
      await tester.pump();
      creation.chain.held!.complete(true);
      await tester.pump();
      expect(creation.bed.settings.savedMultisigs, isEmpty);
      wipe.complete();
      await expectLater(logout, throwsStateError);

      creation.chain
        ..held = null
        ..indexed = true;
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      expect(creation.bed.settings.savedMultisigs.single.accountId, _oldMultisig.accountId);
      expect(creation.bed.pushRegistration.registeredAddresses, [_oldMultisig.accountId]);
      expect(creation.container.read(globalToastProvider)?.type, ToastType.success);
      creation.container.dispose();
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

    group('a proposal going out', () {
      Future<
        ({WalletTestBed bed, _Indexer indexer, _Multisigs chain, ProviderContainer container, Future<String> sent})
      >
      proposing(WidgetTester tester) async {
        final bed = WalletTestBed();
        final indexer = _Indexer();
        final chain = _Multisigs();
        final container = ProviderContainer(
          overrides: [
            ...bed.overrides,
            chainHistoryServiceProvider.overrideWithValue(indexer),
            multisigServiceProvider.overrideWithValue(chain),
          ],
        );
        container.read(notificationProvider);
        await tester.pump();
        final member = makeAccount(1);
        final sent = container
            .read(transactionSubmissionServiceProvider)
            .proposeTransfer(
              msig: MultisigAccount(
                name: 'Multisig',
                accountId: 'qzMultisig',
                signers: [member.accountId, 'qzOther'],
                threshold: 2,
                nonce: BigInt.zero,
                myMemberAccountId: member.accountId,
              ),
              signer: member,
              recipient: 'qzTo',
              amount: BigInt.one,
              expiryBlock: 10,
              feeBreakdown: ProposeFeeBreakdown(
                networkFee: BigInt.zero,
                deposit: BigInt.zero,
                creationFee: BigInt.zero,
                expiryBlock: 10,
              ),
            );
        return (bed: bed, indexer: indexer, chain: chain, container: container, sent: sent);
      }

      testWidgets('that answers after a reset is not tracked', (tester) async {
        final proposal = await proposing(tester);

        await proposal.container.read(logoutServiceProvider).logout();
        await tester.pump();
        proposal.chain.accepted.complete(Uint8List.fromList([1]));
        expect(await proposal.sent, '0x01');
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();

        expect(proposal.indexer.proposalReads, 0);
        expect(proposal.container.read(pendingMultisigProposalsProvider), isEmpty);
        proposal.container.dispose();
      });

      testWidgets('that answers during a wipe that then fails leaves no row stuck as pending', (tester) async {
        final proposal = await proposing(tester);
        final wipe = proposal.bed.substrate.holdWipe = Completer<void>();
        proposal.bed.substrate.logoutError = StateError('the wipe failed');

        final logout = proposal.container.read(logoutServiceProvider).logout();
        await tester.pump();
        proposal.chain.accepted.complete(Uint8List.fromList([1]));
        expect(await proposal.sent, '0x01');
        wipe.complete();
        await expectLater(logout, throwsStateError);
        await tester.pump();

        expect(proposal.indexer.proposalReads, 0);
        expect(proposal.container.read(pendingMultisigProposalsProvider), isEmpty);
        proposal.container.dispose();
      });

      testWidgets('with no reset is tracked', (tester) async {
        final proposal = await proposing(tester);

        proposal.chain.accepted.complete(Uint8List.fromList([1]));
        expect(await proposal.sent, '0x01');
        await tester.pump();

        expect(proposal.indexer.proposalReads, 1);
        expect(proposal.container.read(pendingMultisigProposalsProvider).single.extrinsicHash, '0x01');
        proposal.container.read(multisigProposalPollingServiceProvider).stopAll();
        proposal.container.dispose();
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
