import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/background_mode_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/providers/wallet_presence_provider.dart';
import 'package:quantus_desktop_wallet/services/incoming_activity_notifications.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_desktop_wallet/services/own_activity_notifications.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/encrypted_send_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
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

/// Settings that take a multisig being added or removed: the list in the app
/// is what the tests go by.
class _Settings extends FakeSettingsService {
  _Settings({super.activeAccount, super.multisigs});

  @override
  Future<void> addMultisigAccount(MultisigAccount account) async {}

  @override
  Future<void> removeMultisigAccount(String accountId) async {}
}

/// 12.5 tokens.
final _amount = oneToken * BigInt.from(25) ~/ BigInt.two;
const _onePoll = IncomingActivityNotifications.pollInterval;

typedef _Wallet = ({
  ProviderContainer container,
  FakeNotificationPlugin notifications,
  _RecordingTelemetry telemetry,
  FakeSendChain chain,
  FakeNetwork network,
  List<Account> accounts,
});

/// A wallet of Main, Savings and an Encrypted account, with the Team
/// multisig, open and online, its notifications started in the language
/// [locale]. The indexer holds what [before] gives it by the time the wallet
/// opens.
Future<_Wallet> _open(
  WidgetTester tester, {
  String locale = 'en',
  List<Account> accounts = const [mainAccount, savingsAccount, encryptedAccount],
  List<MultisigAccount>? multisigs,
  void Function(FakeSendChain chain)? before,
}) async {
  SharedPreferences.setMockInitialValues({});
  final chain = FakeSendChain();
  before?.call(chain);
  final notifications = FakeNotificationPlugin();
  final telemetry = _RecordingTelemetry();
  final network = FakeNetwork();
  final held = [...accounts];
  final container = ProviderContainer(
    overrides: [
      ...shellOverrides(
        loadAccounts: () async => [...held],
        settings: _Settings(activeAccount: const RegularAccount(mainAccount), multisigs: multisigs ?? [teamMultisig])
          ..locale = locale,
        chain: chain,
      ),
      notificationPluginProvider.overrideWithValue(notifications),
      telemetryProvider.overrideWithValue(telemetry),
      logoutServiceProvider.overrideWithValue(_NoLogout()),
      networkStatusProvider.overrideWith((ref) => network.statusStream),
    ],
  );
  await container.read(desktopLocalNotificationsProvider.notifier).start();
  container.read(ownActivityNotificationsProvider);
  // Watched, as the app watches it: what a provider nobody listens to listens
  // to is paused, the network's status among it.
  container.listen(incomingActivityNotificationsProvider, (_, _) {});
  for (var i = 0; i < 20; i++) {
    await tester.pump();
  }
  expect(container.read(accountsProvider).hasValue, isTrue);
  expect(container.read(multisigAccountsProvider).hasValue, isTrue);
  expect(chain.receivedReads, isNotEmpty, reason: 'the accounts are read as soon as they are known');
  return (
    container: container,
    notifications: notifications,
    telemetry: telemetry,
    chain: chain,
    network: network,
    accounts: held,
  );
}

/// A test on an open wallet. The wallet is closed at its end: a watch left
/// running would be a timer still pending.
void _test(
  String description,
  Future<void> Function(WidgetTester tester, _Wallet wallet) body, {
  String locale = 'en',
  List<Account> accounts = const [mainAccount, savingsAccount, encryptedAccount],
  List<MultisigAccount>? multisigs,
  void Function(FakeSendChain chain)? before,
}) => testWidgets(description, (tester) async {
  final wallet = await _open(tester, locale: locale, accounts: accounts, multisigs: multisigs, before: before);
  await body(tester, wallet);
  wallet.container.dispose();
}, variant: TargetPlatformVariant.only(TargetPlatform.windows));

var _transfers = 0;

/// A transfer of 12.5 to [to], from Alice unless said, in the transaction
/// [hash].
TransferEvent _transfer({required String to, String from = 'qzAlice', String? hash}) {
  final n = ++_transfers;
  return TransferEvent(
    id: 'transfer-$n',
    from: from,
    to: to,
    amount: _amount,
    timestamp: DateTime(2026, 11, 24, 12),
    fee: BigInt.zero,
    extrinsicHash: hash ?? '0xtransfer$n',
    blockNumber: 10,
    blockHash: '0xblock',
  );
}

/// A reversible transfer of 12.5 from Alice scheduled to [to].
ReversibleTransferEvent _scheduled({required String to}) {
  final n = ++_transfers;
  return ReversibleTransferEvent(
    id: 'scheduled-$n',
    from: 'qzAlice',
    to: to,
    amount: _amount,
    timestamp: DateTime(2026, 11, 24, 12),
    txId: '0xtx$n',
    status: ReversibleTransferStatus.SCHEDULED,
    scheduledAt: DateTime(2026, 11, 25, 12),
    extrinsicHash: '0xscheduled$n',
    blockNumber: 10,
    blockHash: '0xblock',
  );
}

/// A multisig that needs all three of its signers, Main among them.
final _board = MultisigAccount(
  name: 'Board',
  accountId: 'qzBoard',
  signers: const ['qzMain', 'qzOther', 'qzThird'],
  threshold: 3,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

/// A multisig any one of its signers can spend from, Main among them.
final _either = MultisigAccount(
  name: 'Either',
  accountId: 'qzEither',
  signers: const ['qzMain', 'qzOther'],
  threshold: 1,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

const _created = MultisigProposalActivityKind.created;
const _signed = MultisigProposalActivityKind.signed;
const _ready = MultisigProposalActivityKind.ready;
const _executed = MultisigProposalActivityKind.executed;
const _cancelled = MultisigProposalActivityKind.cancelled;
const _removed = MultisigProposalActivityKind.removed;

/// The indexer now holds that [kind] happened to a proposal of [msig], Team
/// unless said, to send 12.5 to Bob: done by Other unless said. With
/// [transfer] false the proposal is something other than a transfer.
void _happens(
  FakeSendChain chain,
  MultisigProposalActivityKind kind, {
  MultisigAccount? msig,
  String by = 'qzOther',
  int? approvals,
  bool? succeeded,
  bool transfer = true,
}) {
  final multisig = msig ?? teamMultisig;
  final n = ++_transfers;
  final when = DateTime(2026, 11, 24, 12);
  chain.proposalActivity
      .putIfAbsent(multisig.accountId, () => [])
      .add(
        MultisigProposalActivity(
          kind: kind,
          id: '${kind.name}-$n',
          timestamp: when,
          proposal: MultisigProposal(
            entityId: '${multisig.accountId}-1',
            id: 1,
            multisigAddress: multisig.accountId,
            proposer: 'qzOther',
            createdAt: when,
            updatedAt: when,
            pallet: '',
            call: '',
            recipient: transfer ? 'qzBob' : '',
            amount: transfer ? _amount : BigInt.zero,
            expiryBlock: 1284220,
            approvals: const ['qzOther'],
            deposit: BigInt.zero,
            status: MultisigProposalStatus.active,
            threshold: multisig.threshold,
            signerCount: multisig.signers.length,
          ),
          creationHash: '0xcreated',
          actor: by,
          approvalsCount: approvals,
          succeeded: succeeded,
        ),
      );
}

const _send = 'Send 12.5 QTC from Team';

Future<void> _advance(WidgetTester tester, [Duration by = _onePoll]) async {
  await tester.pump(by);
  await tester.pump();
}

/// Lets a change to what the wallet watches reach it, with no time passing:
/// each provider in the way is rebuilt on a timer of its own.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(Duration.zero);
  }
}

Iterable<(String, String)> _shown(_Wallet wallet) => wallet.notifications.shown.map((n) => (n.title, n.body));

const _receivedInMain = ('Received 12.5 QTC', 'In Main');

void main() {
  group('a transfer to one of the wallet\'s accounts', () {
    _test('that arrives while the app runs notifies that it was received, with the amount and the account', (
      tester,
      wallet,
    ) async {
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      expect(wallet.notifications.shown, isEmpty, reason: 'not before the indexer is read again');

      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain]);
      final shown = wallet.notifications.shown.single;
      expect('${shown.title} ${shown.body}', isNot(contains('qz')), reason: 'no address');
    });

    _test('is shown under the id the push server gives the same transfer, for the app\'s to replace a pushed one', (
      tester,
      wallet,
    ) async {
      wallet.chain.receive(
        'qzMain',
        TransferEvent(
          id: '0001146057-3ef3e-000006',
          from: 'qzAlice',
          to: 'qzMain',
          amount: _amount,
          timestamp: DateTime(2026, 11, 24, 12),
          fee: BigInt.zero,
          extrinsicHash: '0xpushed',
          blockNumber: 1146057,
          blockHash: '0x3ef3e',
        ),
      );

      await _advance(tester);

      // Of the name `received_0001146057-3ef3e-000006`.
      expect(wallet.notifications.shown.single.id, 149514113);
    });

    _test('is notified once, however often the indexer is read', (tester, wallet) async {
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));

      await _advance(tester);
      await _advance(tester);
      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain]);
    });

    _test(
      'that arrived before the app started notifies nothing; one after it does',
      before: (chain) => chain.receive('qzMain', _transfer(to: 'qzMain')),
      (tester, wallet) async {
        await _advance(tester);
        expect(wallet.notifications.shown, isEmpty);

        wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
        await _advance(tester);

        expect(_shown(wallet), [_receivedInMain]);
      },
    );

    _test('to an account that is not in front names that account, for its click to open the transfer', (
      tester,
      wallet,
    ) async {
      wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings', hash: '0xtosavings'));

      await _advance(tester);

      expect(_shown(wallet), [('Received 12.5 QTC', 'In Savings')]);
      expect(jsonDecode(wallet.notifications.shown.single.payload), {
        'accountId': 'qzSavings',
        'extrinsicHash': '0xtosavings',
      });
    });

    _test('to a multisig is notified for the multisig', (tester, wallet) async {
      wallet.chain.receive('qzTeam', _transfer(to: 'qzTeam'));

      await _advance(tester);

      expect(_shown(wallet), [('Received 12.5 QTC', 'In Team')]);
    });

    _test('each of several is notified, in the order they arrived', (tester, wallet) async {
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings'));

      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain, _receivedInMain, ('Received 12.5 QTC', 'In Savings')]);
      expect(wallet.notifications.shown.map((n) => n.id).toSet(), hasLength(3), reason: 'none replaces another');
    });

    _test('from another of the wallet\'s own accounts notifies nothing: it is the person\'s own send', (
      tester,
      wallet,
    ) async {
      wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings', from: 'qzMain'));

      await _advance(tester);

      expect(wallet.notifications.shown, isEmpty);
    });

    _test('from a multisig of the wallet is notified: its other signers may have sent it', (tester, wallet) async {
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain', from: 'qzTeam'));

      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain]);
    });

    _test('paid by an Encrypted send from this computer notifies nothing: that send says it was sent', (
      tester,
      wallet,
    ) async {
      wallet.container
          .read(ownActivityNotificationsProvider)
          .onEncryptedSendEnded(
            account: encryptedAccount,
            amount: _amount,
            send: EncryptedSendState(phase: EncryptedSendPhase.succeeded, txHashes: const ['0xfirst', '0xlast']),
          );
      wallet.chain.receive(
        'qzSavings',
        WormholeTransferEvent.receipt(_transfer(to: 'qzSavings', from: 'qzExit', hash: '0xfirst')),
      );

      await _advance(tester);

      expect(wallet.notifications.shown, isEmpty);
    });

    _test('paid by a batch of an Encrypted send still proving its next notifies nothing', (tester, wallet) async {
      wallet.container.read(ownActivityNotificationsProvider).onEncryptedSendSubmitted(const ['0xfirst']);
      wallet.chain.receive(
        'qzSavings',
        WormholeTransferEvent.receipt(_transfer(to: 'qzSavings', from: 'qzExit', hash: '0xfirst')),
      );

      await _advance(tester);

      expect(wallet.notifications.shown, isEmpty);
    });

    _test('paid by an Encrypted send from elsewhere is notified', (tester, wallet) async {
      wallet.chain.receive(
        'qzSavings',
        WormholeTransferEvent.receipt(_transfer(to: 'qzSavings', from: 'qzExit', hash: '0xtheirs')),
      );

      await _advance(tester);

      expect(_shown(wallet), [('Received 12.5 QTC', 'In Savings')]);
    });

    _test('is said in the app language', locale: 'id', (tester, wallet) async {
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      wallet.chain.receive('qzMain', _scheduled(to: 'qzMain'));

      await _advance(tester);

      expect(_shown(wallet), [('12,5 QTC diterima', 'Di Main'), ('12,5 QTC akan masuk', 'Dijadwalkan masuk ke Main')]);
    });
  });

  _test('a reversible transfer scheduled to an account notifies that it is incoming, once', (tester, wallet) async {
    wallet.chain.receive('qzMain', _scheduled(to: 'qzMain'));

    await _advance(tester);
    await _advance(tester);

    expect(_shown(wallet), [('Incoming 12.5 QTC', 'Scheduled to arrive in Main')]);
  });

  group('in a multisig of the wallet, a proposal', () {
    _test('another signer made is notified as new, with what it proposes, for its click to open it', (
      tester,
      wallet,
    ) async {
      _happens(wallet.chain, _created);

      await _advance(tester);

      expect(_shown(wallet), [('New proposal', _send)]);
      // The proposal itself, not only the transaction that created it: one
      // transaction can create several.
      expect(jsonDecode(wallet.notifications.shown.single.payload), {
        'accountId': 'qzTeam',
        'extrinsicHash': '0xcreated',
        'proposalId': 'qzTeam-1',
      });
    });

    _test(
      'another signer signed, with approvals still to come, is notified with how many it has',
      multisigs: [_board],
      (tester, wallet) async {
        _happens(wallet.chain, _signed, msig: _board, approvals: 2);

        await _advance(tester);

        expect(_shown(wallet), [('Proposal signed: 2 of 3', 'Send 12.5 QTC from Board')]);
      },
    );

    _test('another signer gave its last approval is notified once, as ready to execute', (tester, wallet) async {
      _happens(wallet.chain, _signed, approvals: 2);
      _happens(wallet.chain, _ready, approvals: 2);

      await _advance(tester);

      expect(_shown(wallet), [('Proposal ready to execute', _send)]);
    });

    _test(
      'another signer made where one approval is enough is notified once, as ready to execute',
      multisigs: [_either],
      (tester, wallet) async {
        _happens(wallet.chain, _created, msig: _either);
        _happens(wallet.chain, _ready, msig: _either, approvals: 1);

        await _advance(tester);

        expect(_shown(wallet), [('Proposal ready to execute', 'Send 12.5 QTC from Either')]);
      },
    );

    _test('another signer executed is notified, as executed or as failed', (tester, wallet) async {
      _happens(wallet.chain, _executed, succeeded: true);
      _happens(wallet.chain, _executed, succeeded: false);

      await _advance(tester);

      expect(_shown(wallet), [('Proposal executed', _send), ('Proposal execution failed', _send)]);
    });

    _test('another signer cancelled or removed is notified', (tester, wallet) async {
      _happens(wallet.chain, _cancelled);
      _happens(wallet.chain, _removed);

      await _advance(tester);

      expect(_shown(wallet), [('Proposal cancelled', _send), ('Proposal removed', _send)]);
    });

    _test('that is not a transfer names only its multisig', (tester, wallet) async {
      _happens(wallet.chain, _created, transfer: false);

      await _advance(tester);

      expect(_shown(wallet), [('New proposal', 'In Team')]);
    });

    _test(
      'that one of the wallet\'s own accounts acted on notifies nothing, whatever it did',
      multisigs: [teamMultisig, _board],
      (tester, wallet) async {
        _happens(wallet.chain, _created, by: 'qzMain');
        _happens(wallet.chain, _signed, msig: _board, by: 'qzSavings', approvals: 2);
        _happens(wallet.chain, _ready, by: 'qzMain', approvals: 2);
        _happens(wallet.chain, _executed, by: 'qzMain', succeeded: true);
        _happens(wallet.chain, _cancelled, by: 'qzMain');
        _happens(wallet.chain, _removed, by: 'qzSavings');

        await _advance(tester);

        expect(wallet.notifications.shown, isEmpty);
      },
    );

    _test('is notified once, however often the indexer is read, and none replaces another', (tester, wallet) async {
      _happens(wallet.chain, _created);
      _happens(wallet.chain, _cancelled);

      await _advance(tester);
      await _advance(tester);
      await _advance(tester);

      expect(_shown(wallet), [('New proposal', _send), ('Proposal cancelled', _send)]);
      expect(wallet.notifications.shown.map((n) => n.id).toSet(), hasLength(2));
    });

    _test(
      'acted on before the app started notifies nothing; what happens after does',
      before: (chain) => _happens(chain, _created),
      (tester, wallet) async {
        await _advance(tester);
        expect(wallet.notifications.shown, isEmpty);

        _happens(wallet.chain, _cancelled);
        await _advance(tester);

        expect(_shown(wallet), [('Proposal cancelled', _send)]);
      },
    );

    _test('is said in the app language', locale: 'id', multisigs: [teamMultisig, _board], (tester, wallet) async {
      _happens(wallet.chain, _created);
      _happens(wallet.chain, _created, transfer: false);
      _happens(wallet.chain, _signed, msig: _board, approvals: 2);
      _happens(wallet.chain, _ready, approvals: 2);
      _happens(wallet.chain, _executed, succeeded: true);
      _happens(wallet.chain, _executed, succeeded: false);
      _happens(wallet.chain, _cancelled);
      _happens(wallet.chain, _removed);

      await _advance(tester);

      const send = 'Kirim 12,5 QTC dari Team';
      expect(_shown(wallet), [
        ('Proposal baru', send),
        ('Proposal baru', 'Di Team'),
        ('Proposal siap dieksekusi', send),
        ('Proposal dieksekusi', send),
        ('Eksekusi proposal gagal', send),
        ('Proposal dibatalkan', send),
        ('Proposal dihapus', send),
        ('Proposal ditandatangani: 2 dari 3', 'Kirim 12,5 QTC dari Board'),
      ]);
    });
  });

  group('the multisigs read for their proposals', () {
    _test('are the wallet\'s multisigs', multisigs: [teamMultisig, _board], (tester, wallet) async {
      await _advance(tester);

      expect(wallet.chain.proposalActivityReads.length, greaterThan(1));
      for (final read in wallet.chain.proposalActivityReads) {
        expect(read, unorderedEquals(['qzTeam', 'qzBoard']));
      }
    });

    _test('are not asked about in a wallet with none', multisigs: const [], (tester, wallet) async {
      await _advance(tester);

      expect(wallet.chain.proposalActivityReads, isEmpty);
    });

    _test(
      'take in a multisig added later, from then on: what happened in it before is not notified',
      before: (chain) => _happens(chain, _created, msig: _board),
      (tester, wallet) async {
        await wallet.container.read(multisigAccountsProvider.notifier).add(_board);
        await _settle(tester);
        expect(wallet.chain.proposalActivityReads.last, contains('qzBoard'), reason: 'read at once');

        _happens(wallet.chain, _cancelled, msig: _board);
        await _advance(tester);

        expect(_shown(wallet), [('Proposal cancelled', 'Send 12.5 QTC from Board')]);
      },
    );

    _test('start afresh on a multisig removed and added back', (tester, wallet) async {
      final multisigs = wallet.container.read(multisigAccountsProvider.notifier);
      await multisigs.remove('qzTeam');
      await _settle(tester);
      _happens(wallet.chain, _created);
      await _advance(tester);

      await multisigs.add(teamMultisig);
      await _settle(tester);
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty);

      _happens(wallet.chain, _cancelled);
      await _advance(tester);

      expect(_shown(wallet), [('Proposal cancelled', _send)]);
    });

    _test('that cannot be read are reported once while it lasts, and what was received is still notified', (
      tester,
      wallet,
    ) async {
      _happens(wallet.chain, _created);
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      wallet.chain.proposalActivityError = StateError('the indexer is down');

      await _advance(tester);
      await _advance(tester);
      expect(_shown(wallet), [_receivedInMain]);
      expect(wallet.telemetry.errors, ['desktop_notification_proposals_unread']);

      wallet.chain.proposalActivityError = null;
      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain, ('New proposal', _send)]);
    });

    _test('are still read when what was received cannot be', (tester, wallet) async {
      _happens(wallet.chain, _created);
      wallet.chain.receivedError = StateError('the indexer is down');

      await _advance(tester);

      expect(_shown(wallet), [('New proposal', _send)]);
      expect(wallet.telemetry.errors, ['desktop_notification_incoming_unread']);
    });
  });

  group('the accounts read', () {
    _test('are the Transparent accounts and the multisigs, never an Encrypted account', (tester, wallet) async {
      await _advance(tester);

      expect(wallet.chain.receivedReads.length, greaterThan(1));
      for (final read in wallet.chain.receivedReads) {
        expect(read, unorderedEquals(['qzMain', 'qzSavings', 'qzTeam']));
      }
    });

    _test(
      'take in an account added later, from then on: what it received before is not notified',
      accounts: const [mainAccount],
      before: (chain) => chain.receive('qzSavings', _transfer(to: 'qzSavings')),
      (tester, wallet) async {
        wallet.accounts.add(savingsAccount);
        wallet.container.invalidate(accountsProvider);
        await _settle(tester);
        expect(wallet.chain.receivedReads.last, contains('qzSavings'), reason: 'read at once, not a poll later');

        wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings'));
        await _advance(tester);

        expect(_shown(wallet), [('Received 12.5 QTC', 'In Savings')]);
      },
    );

    _test('leave out an account removed, and what it receives is not notified', (tester, wallet) async {
      wallet.accounts.remove(savingsAccount);
      wallet.container.invalidate(accountsProvider);
      await _settle(tester);

      wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings'));
      await _advance(tester);

      expect(wallet.chain.receivedReads.last, unorderedEquals(['qzMain', 'qzTeam']));
      expect(wallet.notifications.shown, isEmpty);
    });

    _test('start afresh on an account removed and added back: what it received meanwhile is not notified', (
      tester,
      wallet,
    ) async {
      wallet.accounts.remove(savingsAccount);
      wallet.container.invalidate(accountsProvider);
      await _settle(tester);
      wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings'));
      await _advance(tester);

      wallet.accounts.add(savingsAccount);
      wallet.container.invalidate(accountsProvider);
      await _settle(tester);
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty);

      wallet.chain.receive('qzSavings', _transfer(to: 'qzSavings'));
      await _advance(tester);

      expect(_shown(wallet), [('Received 12.5 QTC', 'In Savings')]);
    });
  });

  group('what cannot be shown or read', () {
    _test('with notifications turned off in Settings, nothing is shown, then or once they are back on', (
      tester,
      wallet,
    ) async {
      final config = wallet.container.read(notificationConfigProvider.notifier);
      await config.updateConfig(wallet.container.read(notificationConfigProvider).copyWith(enabled: false));
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty);

      await config.updateConfig(wallet.container.read(notificationConfigProvider).copyWith(enabled: true));
      await _advance(tester);

      expect(wallet.notifications.shown, isEmpty, reason: 'no burst of what was passed over');
    });

    _test('a read that fails shows nothing and is reported; the next one that works delivers', (tester, wallet) async {
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      wallet.chain.receivedError = StateError('the indexer is down');

      await _advance(tester);
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty);
      expect(wallet.telemetry.errors, ['desktop_notification_incoming_unread'], reason: 'once, while it lasts');

      wallet.chain.receivedError = null;
      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain]);

      wallet.chain.receivedError = StateError('down again');
      await _advance(tester);
      expect(wallet.telemetry.errors, hasLength(2), reason: 'a new failure is reported again');
    });

    _test('offline, the indexer is not read; back online, what arrived meanwhile is notified at once', (
      tester,
      wallet,
    ) async {
      wallet.network.goOffline();
      await _settle(tester);
      final readsWhenOffline = wallet.chain.receivedReads.length;
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));

      await _advance(tester);
      await _advance(tester);
      expect(wallet.chain.receivedReads, hasLength(readsWhenOffline));

      wallet.network.goOnline();
      await _settle(tester);

      expect(_shown(wallet), [_receivedInMain]);
    });

    _test('with the window closed the indexer is not read; reopened, what arrived meanwhile is notified at once', (
      tester,
      wallet,
    ) async {
      wallet.container.read(windowClosedProvider.notifier).set(true);
      await _settle(tester);
      final readsWhenClosed = wallet.chain.receivedReads.length;
      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));

      await _advance(tester);
      await _advance(tester);
      expect(wallet.chain.receivedReads, hasLength(readsWhenClosed));

      wallet.container.read(windowClosedProvider.notifier).set(false);
      await _settle(tester);

      expect(_shown(wallet), [_receivedInMain]);
    });
  });

  testWidgets('the app notifies what its accounts receive for as long as it runs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final chain = FakeSendChain();
    final notifications = FakeNotificationPlugin();
    await pumpShell(
      tester,
      overrides: shellOverrides(
        accounts: const [mainAccount],
        settings: FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: {'qzMain': oneToken},
        chain: chain,
      ),
      notifications: notifications,
    );

    chain.receive('qzMain', _transfer(to: 'qzMain'));
    await _advance(tester);

    expect(notifications.shown.map((n) => (n.title, n.body)), [_receivedInMain]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  group('at a wallet reset', () {
    for (final kind in ['of what was received', 'of what happened to proposals']) {
      _test('a read $kind answered after the wallet was wiped notifies nothing', (tester, wallet) async {
        wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
        _happens(wallet.chain, _created);
        final held = Completer<void>();
        if (kind == 'of what was received') {
          wallet.chain.holdReceived = held;
        } else {
          wallet.chain.holdProposalActivity = held;
        }
        await _advance(tester);
        final shownBefore = wallet.notifications.shown.length;
        expect(shownBefore, 1, reason: 'the other read was answered');

        final session = wallet.container.read(walletSessionProvider)..beginReset();
        session.finishReset();
        await wallet.container.read(walletPresenceProvider.notifier).wipeWallet();
        held.complete();
        await _settle(tester);

        expect(wallet.notifications.shown, hasLength(shownBefore));
      });
    }

    _test('the indexer is no longer read, and the next wallet starts from what it holds then', (tester, wallet) async {
      final session = wallet.container.read(walletSessionProvider)..beginReset();
      session.finishReset();
      await wallet.container.read(walletPresenceProvider.notifier).wipeWallet();
      await _settle(tester);
      final readsAtTheWipe = wallet.chain.receivedReads.length;

      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      _happens(wallet.chain, _created);
      await _advance(tester);
      await _advance(tester);
      expect(wallet.chain.receivedReads, hasLength(readsAtTheWipe));

      wallet.container.read(walletPresenceProvider.notifier).walletAdded();
      await _settle(tester);
      await _advance(tester);
      expect(wallet.notifications.shown, isEmpty, reason: 'received before this wallet was here');

      wallet.chain.receive('qzMain', _transfer(to: 'qzMain'));
      _happens(wallet.chain, _cancelled);
      await _advance(tester);

      expect(_shown(wallet), [_receivedInMain, ('Proposal cancelled', _send)]);
    });
  });
}
