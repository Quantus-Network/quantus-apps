import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/pending_transactions_provider.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/pending_transaction_polling_service.dart';
import 'package:wallet_core/services/telemetry.dart';

import '../fakes.dart';
import 'fake_notification_plugin.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

/// 12.5 tokens.
final _amount = oneToken * BigInt.from(25) ~/ BigInt.two;
final _broadcastAt = DateTime(2026, 11, 21, 12);
const _sendId = 'tx-1';
const _sendHash = '0xsend';
const _proposalId = 'proposal-1';
const _proposalHash = '0xproposal';

/// The transfer the indexer holds for Main's send to Bob, of [amount].
TransferEvent _indexedSend(BigInt amount) => TransferEvent(
  id: 'indexed-send',
  from: mainAccount.accountId,
  to: 'qzBob',
  amount: amount,
  timestamp: _broadcastAt,
  fee: BigInt.zero,
  extrinsicHash: _sendHash,
  blockNumber: 10,
  blockHash: '0xblock',
);

/// The chain, its indexer holding Main's send to Bob as having moved
/// [sentAmount], or not holding it when that is null.
FakeSendChain _chain({required BigInt? sentAmount}) {
  final chain = FakeSendChain();
  if (sentAmount != null) chain.indexedTransfers[_sendHash] = _indexedSend(sentAmount);
  return chain;
}

/// A wallet of Main and Savings, with the Team multisig, whose notifications
/// are started on [platform] in the language [locale]. The indexer holds
/// Main's send to Bob as having moved [sentAmount], 12.5 unless said.
Future<({ProviderContainer container, FakeNotificationPlugin notifications, _RecordingTelemetry telemetry})> _open({
  TargetPlatform platform = TargetPlatform.windows,
  String locale = 'en',
  BigInt? sentAmount,
  bool indexed = true,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  final notifications = FakeNotificationPlugin();
  final telemetry = _RecordingTelemetry();
  final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount), multisigs: [teamMultisig])
    ..locale = locale;
  final container = ProviderContainer(
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: settings,
        chain: _chain(sentAmount: indexed ? sentAmount ?? _amount : null),
      ),
      notificationPluginProvider.overrideWithValue(notifications),
      telemetryProvider.overrideWithValue(telemetry),
    ],
  );
  addTearDown(container.dispose);
  await container.read(desktopLocalNotificationsProvider.notifier).start();
  container.read(ownActivityNotificationsProvider);
  for (var i = 0; i < 100; i++) {
    if (container.read(accountsProvider).hasValue && container.read(multisigAccountsProvider).hasValue) break;
    await Future<void>.delayed(Duration.zero);
  }
  return (container: container, notifications: notifications, telemetry: telemetry);
}

/// Main sends [amount], 12.5 unless said, to Bob and the send is broadcast,
/// as the send sheet does.
void _broadcast(ProviderContainer container, {BigInt? amount}) => withClock(Clock.fixed(_broadcastAt), () {
  final sends = container.read(pendingTransactionsProvider.notifier);
  sends.add(
    PendingTransactionEvent(
      tempId: _sendId,
      from: mainAccount.accountId,
      to: 'qzBob',
      amount: amount ?? _amount,
      fee: BigInt.zero,
      timestamp: _broadcastAt,
    ),
  );
  sends.updateState(_sendId, TransactionState.pending, extrinsicHash: _sendHash);
});

/// What the wallet does once it has found the send on the chain.
void _found(ProviderContainer container) {
  final sends = container.read(pendingTransactionsProvider.notifier);
  sends.updateState(_sendId, TransactionState.inHistory);
  sends.remove(_sendId);
}

/// What the wallet does when it stops watching for a send it never found.
void _givenUp(ProviderContainer container) => withClock(
  Clock.fixed(_broadcastAt.add(PendingTransactionPollingService.timeout + const Duration(seconds: 5))),
  () => container.read(pendingTransactionsProvider.notifier).remove(_sendId),
);

/// Main proposes, in Team, to send 12.5 to Bob, and the proposal is broadcast.
void _propose(ProviderContainer container) {
  final proposals = container.read(pendingMultisigProposalsProvider.notifier);
  proposals.add(
    PendingMultisigProposalEvent(
      tempId: _proposalId,
      multisigAddress: teamMultisig.accountId,
      proposerId: mainAccount.accountId,
      recipient: 'qzBob',
      amount: _amount,
      deposit: BigInt.zero,
      expiryBlock: 100,
      palletFee: BigInt.zero,
    ),
  );
  proposals.update(_proposalId, extrinsicHash: _proposalHash);
}

/// What became of the proposal, as the wallet records it: a created one
/// leaves the pending proposals first, one never seen after.
void _settle(ProviderContainer container, SendConfirmation outcome) {
  final proposals = container.read(pendingMultisigProposalsProvider.notifier);
  final confirmations = container.read(multisigProposalConfirmationsProvider.notifier);
  if (outcome == SendConfirmation.confirmed) {
    proposals.remove(_proposalId);
    confirmations.settle(_proposalHash, outcome);
  } else {
    confirmations.settle(_proposalHash, outcome);
    proposals.remove(_proposalId);
  }
}

/// Lets what was started finish.
Future<void> _settleDown() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Iterable<(String, String)> _shown(FakeNotificationPlugin notifications) =>
    notifications.shown.map((n) => (n.title, n.body));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a Transparent send from this computer', () {
    test('that the chain confirms notifies that it was sent, with the amount and the account it came from', () async {
      final (:container, :notifications, telemetry: _) = await _open();

      _broadcast(container);
      await _settleDown();

      // Nothing yet: it is only on its way.
      expect(notifications.shown, isEmpty);

      _found(container);
      await _settleDown();

      expect(_shown(notifications), [('Sent 12.5 QTC', 'From Main')]);
      expect(jsonDecode(notifications.shown.single.payload), {'accountId': mainAccount.accountId});
    });

    test('sent as Max notifies the amount the chain moved, not the estimate it was recorded with', () async {
      // Max sends everything there is at inclusion, which can be less than
      // what the send sheet estimated.
      final (:container, :notifications, telemetry: _) = await _open(sentAmount: oneToken * BigInt.from(9));

      _broadcast(container, amount: oneToken * BigInt.from(10));
      _found(container);
      await _settleDown();

      expect(_shown(notifications), [('Sent 9 QTC', 'From Main')]);
    });

    test('found, but not in the indexer when its amount is read, notifies nothing and is reported', () async {
      final (:container, :notifications, :telemetry) = await _open(indexed: false);

      _broadcast(container);
      _found(container);
      await _settleDown();

      expect(notifications.shown, isEmpty);
      expect(telemetry.errors, ['desktop_notification_sent_amount_unread']);
    });

    test('that the wallet stops watching for unfound notifies that it was not confirmed', () async {
      final (:container, :notifications, telemetry: _) = await _open();

      _broadcast(container);
      _givenUp(container);
      await _settleDown();

      expect(_shown(notifications), [
        (
          'Send not confirmed',
          '12.5 QTC from Main wasn’t seen on the chain in time. It may have failed, or only be late.',
        ),
      ]);
    });

    test('that is marked failed notifies that it failed', () async {
      final (:container, :notifications, telemetry: _) = await _open();

      _broadcast(container);
      container.read(pendingTransactionsProvider.notifier).updateState(_sendId, TransactionState.failed);
      container.read(pendingTransactionsProvider.notifier).remove(_sendId);
      await _settleDown();

      expect(_shown(notifications), [('Send failed', '12.5 QTC from Main was not sent.')]);
    });

    test('whose broadcast failed notifies nothing: the send sheet says so', () async {
      final (:container, :notifications, telemetry: _) = await _open();
      final sends = container.read(pendingTransactionsProvider.notifier);

      sends.add(
        PendingTransactionEvent(
          tempId: _sendId,
          from: mainAccount.accountId,
          to: 'qzBob',
          amount: _amount,
          fee: BigInt.zero,
          timestamp: _broadcastAt,
        ),
      );
      sends.remove(_sendId);
      await _settleDown();

      expect(notifications.shown, isEmpty);
    });

    test('still watched for when the wallet is wiped notifies nothing about it', () async {
      final (:container, :notifications, telemetry: _) = await _open();

      _broadcast(container);
      // The wipe empties the pending sends at once.
      withClock(
        Clock.fixed(_broadcastAt.add(const Duration(minutes: 1))),
        () => container.read(pendingTransactionsProvider.notifier).clear(),
      );
      await _settleDown();

      expect(notifications.shown, isEmpty);
    });
  });

  group('a proposal made on this computer', () {
    test('that the chain creates notifies that it was created, with what it sends and from which multisig', () async {
      final (:container, :notifications, telemetry: _) = await _open();

      _propose(container);
      _settle(container, SendConfirmation.confirmed);
      await _settleDown();

      expect(_shown(notifications), [('Proposal created', 'Send 12.5 QTC from Team')]);
      expect(jsonDecode(notifications.shown.single.payload), {'accountId': teamMultisig.accountId});
    });

    test('not seen in time notifies that it was not confirmed', () async {
      final (:container, :notifications, telemetry: _) = await _open();

      _propose(container);
      _settle(container, SendConfirmation.unconfirmed);
      await _settleDown();

      expect(_shown(notifications), [
        ('Proposal not confirmed', 'The proposal to send 12.5 QTC from Team wasn’t seen on the chain in time.'),
      ]);
    });
  });

  test('with notifications turned off in Settings, nothing is shown', () async {
    final (:container, :notifications, telemetry: _) = await _open();
    final config = container.read(notificationConfigProvider.notifier);
    await config.updateConfig(container.read(notificationConfigProvider).copyWith(enabled: false));

    _broadcast(container);
    _found(container);
    _propose(container);
    _settle(container, SendConfirmation.confirmed);
    await _settleDown();

    expect(notifications.shown, isEmpty);
  });

  test('while the system does not allow notifications, nothing is shown and nothing fails', () async {
    // macOS, not asked yet.
    final (:container, :notifications, telemetry: _) = await _open(platform: TargetPlatform.macOS);

    _broadcast(container);
    _found(container);
    await _settleDown();

    expect(notifications.shown, isEmpty);
  });

  testOnWindowsAndLinux('the app watches what it does from the start', (tester) async {
    final notifications = FakeNotificationPlugin();
    await pumpShell(
      tester,
      notifications: notifications,
      overrides: shellOverrides(
        accounts: const [mainAccount, savingsAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        chain: _chain(sentAmount: _amount),
      ),
    );
    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

    _broadcast(container);
    _found(container);
    await tester.pumpAndSettle();

    expect(_shown(notifications), [('Sent 12.5 QTC', 'From Main')]);
  });

  test('once macOS stops allowing notifications, a send notifies nothing', () async {
    final (:container, :notifications, telemetry: _) = await _open(platform: TargetPlatform.macOS);
    final desktop = container.read(desktopLocalNotificationsProvider.notifier);
    await desktop.requestPermission();
    notifications.grants = false;
    await desktop.recheckPermission();

    _broadcast(container);
    _found(container);
    await _settleDown();

    expect(notifications.shown, isEmpty);
  });

  test('the text follows the app language', () async {
    final (:container, :notifications, telemetry: _) = await _open(locale: 'id');

    _broadcast(container);
    _found(container);
    await _settleDown();

    expect(_shown(notifications), [('12,5 QTC terkirim', 'Dari Main')]);
  });
}
