import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_session.dart';

import '../fakes.dart';
import 'fake_notification_plugin.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

class _NoLogout extends Fake implements LogoutService {
  @override
  Future<void> logout() async {}
}

/// 12.5 tokens.
final _amount = oneToken * BigInt.from(25) ~/ BigInt.two;
const _onePoll = Duration(seconds: 6);
const _pastTheWatch = Duration(minutes: 5, seconds: 10);

typedef _Wallet = ({
  ProviderContainer container,
  FakeNotificationPlugin notifications,
  _RecordingTelemetry telemetry,
  FakeSendChain chain,
  _Reloads reloads,
});

/// When [held] is set, reading the Encrypted account again waits for it.
class _Reloads {
  Completer<void>? held;

  /// How many times the Encrypted account was read.
  int reads = 0;
}

Future<_Wallet> _open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final chain = FakeSendChain();
  final notifications = FakeNotificationPlugin();
  final telemetry = _RecordingTelemetry();
  final reloads = _Reloads();
  final container = ProviderContainer(
    overrides: [
      ...shellOverrides(
        accounts: const [mainAccount, encryptedAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        chain: chain,
        holdEncryptedState: () {
          reloads.reads++;
          return reloads.held;
        },
      ),
      notificationPluginProvider.overrideWithValue(notifications),
      telemetryProvider.overrideWithValue(telemetry),
      logoutServiceProvider.overrideWithValue(_NoLogout()),
    ],
  );
  await container.read(desktopLocalNotificationsProvider.notifier).start();
  container.read(ownActivityNotificationsProvider);
  for (var i = 0; i < 20 && !container.read(accountsProvider).hasValue; i++) {
    await tester.pump();
  }
  return (container: container, notifications: notifications, telemetry: telemetry, chain: chain, reloads: reloads);
}

/// A test on an open wallet. The wallet is closed at its end: a watch left
/// running would be a timer still pending.
void _test(String description, Future<void> Function(WidgetTester tester, _Wallet wallet) body) =>
    testWidgets(description, (tester) async {
      final wallet = await _open(tester);
      await body(tester, wallet);
      wallet.container.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

void _ended(_Wallet wallet, EncryptedSendState send) => wallet.container
    .read(ownActivityNotificationsProvider)
    .onEncryptedSendEnded(account: encryptedAccount, amount: _amount, send: send);

void _handedOver(_Wallet wallet, List<String> hashes) =>
    _ended(wallet, EncryptedSendState(phase: EncryptedSendPhase.succeeded, txHashes: hashes));

/// The indexer now holds the transaction [hash].
void _lands(_Wallet wallet, String hash) => wallet.chain.indexedTransfers[hash] = TransferEvent(
  id: 'indexed-$hash',
  from: 'qzExit',
  to: 'qzBob',
  amount: _amount,
  timestamp: DateTime(2026, 11, 22),
  fee: BigInt.zero,
  extrinsicHash: hash,
  blockNumber: 10,
  blockHash: '0xblock',
);

Future<void> _advance(WidgetTester tester, [Duration by = _onePoll]) async {
  await tester.pump(by);
  await tester.pump();
}

Iterable<(String, String)> _shown(_Wallet wallet) => wallet.notifications.shown.map((n) => (n.title, n.body));

const _sent = ('Sent 12.5 QTC', 'From Encrypted Account');
const _notConfirmed = (
  'Send not confirmed',
  '12.5 QTC from Encrypted Account wasn’t seen on the chain in time. It may have failed, or only be late.',
);

void main() {
  group('a send handed to the node', () {
    _test('shows nothing until the chain has it, then that it was sent, with its hash', (tester, wallet) async {
      _handedOver(wallet, ['0xonly']);
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty);

      _lands(wallet, '0xonly');
      await _advance(tester);

      expect(_shown(wallet), [_sent]);
      expect(jsonDecode(wallet.notifications.shown.single.payload), {
        'accountId': encryptedAccount.accountId,
        'extrinsicHash': '0xonly',
      });
    });

    _test('of several batches waits for all of them, notifies once, and carries the last', (tester, wallet) async {
      _handedOver(wallet, ['0xfirst', '0xlast']);
      _lands(wallet, '0xlast');
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty);

      _lands(wallet, '0xfirst');
      await _advance(tester);
      await _advance(tester);

      expect(_shown(wallet), [_sent]);
      expect(jsonDecode(wallet.notifications.shown.single.payload)['extrinsicHash'], '0xlast');
    });

    _test('not seen in time notifies that it was not confirmed, with its hash', (tester, wallet) async {
      _handedOver(wallet, ['0xonly']);

      await _advance(tester, _pastTheWatch);

      expect(_shown(wallet), [_notConfirmed]);
      expect(jsonDecode(wallet.notifications.shown.single.payload)['extrinsicHash'], '0xonly');
    });

    _test('when the indexer cannot be read, keeps watching and reports it once', (tester, wallet) async {
      wallet.chain.transferLookupError = StateError('the indexer is down');
      _handedOver(wallet, ['0xonly']);
      await _advance(tester);
      await _advance(tester);
      expect(wallet.telemetry.errors, ['desktop_notification_encrypted_send_unread']);
      expect(wallet.notifications.shown, isEmpty);

      wallet.chain.transferLookupError = null;
      _lands(wallet, '0xonly');
      await _advance(tester);

      expect(_shown(wallet), [_sent]);
    });

    _test('whose indexer never recovers ends as not confirmed', (tester, wallet) async {
      wallet.chain.transferLookupError = StateError('the indexer is down');
      _handedOver(wallet, ['0xonly']);

      await _advance(tester, _pastTheWatch);

      expect(_shown(wallet), [_notConfirmed]);
      expect(wallet.telemetry.errors, ['desktop_notification_encrypted_send_unread']);
    });

    _test('still watched for when the wallet is wiped notifies nothing, and the watching stops', (
      tester,
      wallet,
    ) async {
      _handedOver(wallet, ['0xonly']);
      await _advance(tester);

      await wallet.container.read(walletPresenceProvider.notifier).wipeWallet();
      await tester.pump();
      final readsAtTheWipe = wallet.chain.transferLookups.length;
      _lands(wallet, '0xonly');
      await _advance(tester, _pastTheWatch);

      expect(wallet.notifications.shown, isEmpty);
      expect(wallet.chain.transferLookups, hasLength(readsAtTheWipe));
    });

    group('at a wallet reset', () {
      Set<Object> holds(_Wallet wallet) => wallet.container.read(workHoldsProvider);

      /// Ends a wipe that went through, as `wipeWallet` does around the real one.
      Future<void> wiped(WidgetTester tester, _Wallet wallet, WalletSession session) async {
        session.finishReset();
        await wallet.container.read(walletPresenceProvider.notifier).wipeWallet();
        await _advance(tester);
      }

      /// A send on the chain, its search answering once the wipe has started.
      Future<WalletSession> answeredDuringTheWipe(WidgetTester tester, _Wallet wallet) async {
        final search = wallet.chain.holdHashSearch = Completer<void>();
        _handedOver(wallet, ['0xonly']);
        await tester.pump();
        final session = wallet.container.read(walletSessionProvider)..beginReset();
        _lands(wallet, '0xonly');
        search.complete();
        await tester.pump();
        await tester.pump();
        return session;
      }

      /// A send on the chain, the account read again after it once the wipe
      /// has started.
      Future<WalletSession> reloadedDuringTheWipe(WidgetTester tester, _Wallet wallet) async {
        final reload = wallet.reloads.held = Completer<void>();
        _handedOver(wallet, ['0xonly']);
        _lands(wallet, '0xonly');
        await tester.pump();
        await tester.pump();
        final session = wallet.container.read(walletSessionProvider)..beginReset();
        reload.complete();
        await tester.pump();
        await tester.pump();
        return session;
      }

      /// A send past its watch, its final check answering during the wipe.
      Future<WalletSession> gaveUpDuringTheWipe(WidgetTester tester, _Wallet wallet) async {
        _handedOver(wallet, ['0xonly']);
        await tester.pump(const Duration(minutes: 5, seconds: 2));
        final search = wallet.chain.holdHashSearch = Completer<void>();
        await tester.pump(const Duration(seconds: 5));
        final session = wallet.container.read(walletSessionProvider)..beginReset();
        search.complete();
        await tester.pump();
        await tester.pump();
        return session;
      }

      _test('found during a wipe that goes through notifies nothing and lets the app go', (tester, wallet) async {
        final readsBefore = wallet.reloads.reads;
        final session = await answeredDuringTheWipe(tester, wallet);
        expect(wallet.notifications.shown, isEmpty);
        expect(wallet.reloads.reads, readsBefore, reason: 'the Encrypted account is not read during the wipe');

        await wiped(tester, wallet, session);

        expect(wallet.notifications.shown, isEmpty);
        expect(holds(wallet), isEmpty);
      });

      _test('found during a wipe that fails notifies after it', (tester, wallet) async {
        final session = await answeredDuringTheWipe(tester, wallet);
        expect(wallet.notifications.shown, isEmpty);
        expect(holds(wallet), isNotEmpty);

        session.cancelReset();
        await _advance(tester);

        expect(_shown(wallet), [_sent]);
        expect(holds(wallet), isEmpty);
      });

      _test('read again during a wipe that goes through notifies nothing and lets the app go', (tester, wallet) async {
        final session = await reloadedDuringTheWipe(tester, wallet);
        expect(wallet.notifications.shown, isEmpty);

        await wiped(tester, wallet, session);

        expect(wallet.notifications.shown, isEmpty);
        expect(holds(wallet), isEmpty);
      });

      _test('read again during a wipe that fails notifies after it', (tester, wallet) async {
        final session = await reloadedDuringTheWipe(tester, wallet);
        expect(wallet.notifications.shown, isEmpty);
        expect(holds(wallet), isNotEmpty);

        session.cancelReset();
        await _advance(tester);

        expect(_shown(wallet), [_sent]);
        expect(holds(wallet), isEmpty);
      });

      _test('timing out during a wipe that goes through says nothing', (tester, wallet) async {
        final session = await gaveUpDuringTheWipe(tester, wallet);
        expect(wallet.notifications.shown, isEmpty);

        await wiped(tester, wallet, session);

        expect(wallet.notifications.shown, isEmpty);
        expect(holds(wallet), isEmpty);
      });

      _test('timing out during a wipe that fails says so after it', (tester, wallet) async {
        final session = await gaveUpDuringTheWipe(tester, wallet);
        expect(wallet.notifications.shown, isEmpty);

        session.cancelReset();
        await _advance(tester);

        expect(_shown(wallet), [_notConfirmed]);
        expect(holds(wallet), isEmpty);
      });
    });

    _test('with notifications turned off in Settings shows nothing', (tester, wallet) async {
      final config = wallet.container.read(notificationConfigProvider.notifier);
      await config.updateConfig(wallet.container.read(notificationConfigProvider).copyWith(enabled: false));

      _handedOver(wallet, ['0xonly']);
      _lands(wallet, '0xonly');
      await _advance(tester);

      expect(wallet.notifications.shown, isEmpty);
    });
  });

  group('a send that ends before the chain', () {
    _test('by failing says it did not finish, as part of it may have gone through', (tester, wallet) async {
      _ended(wallet, EncryptedSendState(phase: EncryptedSendPhase.failed, errorMessage: 'The network refused it'));
      await tester.pump();

      expect(_shown(wallet), [
        ('Send failed', '12.5 QTC from Encrypted Account didn’t finish sending. Part of it may have gone through.'),
      ]);
      expect(jsonDecode(wallet.notifications.shown.single.payload), {'accountId': encryptedAccount.accountId});
    });

    _test('because the balance changed says it was not sent', (tester, wallet) async {
      _ended(wallet, EncryptedSendState(phase: EncryptedSendPhase.planStale));
      await tester.pump();

      expect(_shown(wallet), [('Send failed', '12.5 QTC from Encrypted Account was not sent.')]);
    });

    _test('because the person cancelled shows nothing, even with part of it paid', (tester, wallet) async {
      _ended(wallet, EncryptedSendState(phase: EncryptedSendPhase.cancelled));
      _ended(
        wallet,
        EncryptedSendState(
          phase: EncryptedSendPhase.cancelled,
          submittedRecipientToken: oneToken,
          txHashes: const ['0xpaid'],
        ),
      );
      _lands(wallet, '0xpaid');
      await _advance(tester);

      expect(wallet.notifications.shown, isEmpty);
    });

    _test('while still running shows nothing', (tester, wallet) async {
      _ended(wallet, EncryptedSendState(phase: EncryptedSendPhase.running));
      _ended(wallet, EncryptedSendState(phase: EncryptedSendPhase.canceling));
      await tester.pump();

      expect(wallet.notifications.shown, isEmpty);
    });
  });
}
