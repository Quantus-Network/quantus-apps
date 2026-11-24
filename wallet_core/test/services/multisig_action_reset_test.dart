import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/filtered_transactions_params.dart';
import 'package:wallet_core/providers/account_id_list_cache.dart';
import 'package:wallet_core/providers/filtered_all_transactions_provider.dart';
import 'package:wallet_core/providers/global_toast_provider.dart';
import 'package:wallet_core/providers/multisig_proposal_confirmations_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_provider.dart';
import 'package:wallet_core/providers/pending_multisig_approvals_provider.dart';
import 'package:wallet_core/providers/pending_multisig_cancellations_provider.dart';
import 'package:wallet_core/providers/pending_multisig_executions_provider.dart';
import 'package:wallet_core/providers/pending_multisig_proposals_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/logout_service.dart';
import 'package:wallet_core/services/multisig_proposal_polling_service.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';

import '../fakes.dart';

const _hash = '0x01';
const _proposalHash = '0xproposal';
final _member = makeAccount(1);
final _msig = MultisigAccount(
  name: 'Old multisig',
  accountId: 'qzOldMultisig',
  signers: [_member.accountId, 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: _member.accountId,
);

MultisigProposal _proposal(MultisigProposalStatus status, {List<String> approvals = const []}) => MultisigProposal(
  entityId: 'entity',
  id: 7,
  multisigAddress: _msig.accountId,
  proposer: _member.accountId,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  pallet: 'Balances',
  call: 'transfer_allow_death',
  recipient: 'qzTo',
  amount: BigInt.one,
  expiryBlock: 100,
  approvals: approvals,
  deposit: BigInt.zero,
  status: status,
  threshold: 2,
  signerCount: 2,
);

class _Unsigned extends Fake implements UnsignedTransactionData {}

/// The chain: its answer to a broadcast is held until the test gives it, and
/// the read numbered [holdRead] waits for [heldRead].
class _Chain extends Fake implements MultisigService {
  final accepted = Completer<Uint8List>();
  MultisigProposal? proposal;
  int reads = 0;
  int? holdRead;
  final heldRead = Completer<void>();

  /// How many times the member's balance was read.
  int balanceReads = 0;

  @override
  Future<Uint8List> submitApproveExtrinsic({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) => accepted.future;

  @override
  Future<Uint8List> submitExecuteExtrinsic({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
    List<int>? callBytes,
  }) => accepted.future;

  @override
  Future<Uint8List> submitCancelExtrinsic({
    required MultisigAccount msig,
    required Account signer,
    required int proposalId,
  }) => accepted.future;

  @override
  Future<MultisigProposal?> getProposal(MultisigAccount msig, int id) async {
    reads++;
    if (reads == holdRead) await heldRead.future;
    return proposal;
  }
}

/// The indexer: it holds [event], and the search numbered [holdSearch] waits
/// for [heldSearch], then fails if [failHeldSearch].
class _Indexer extends Fake implements ChainHistoryService {
  TransactionEvent? event;
  int searches = 0;
  int? holdSearch;
  bool failHeldSearch = false;
  final heldSearch = Completer<void>();

  Future<T?> _answer<T>() async {
    searches++;
    if (searches == holdSearch) {
      await heldSearch.future;
      if (failHeldSearch) throw StateError('the indexer is down');
    }
    final found = event;
    return found is T ? found as T : null;
  }

  @override
  Future<MultisigProposalApprovedEvent?> searchSignerApprovedByExtrinsicHash({required String extrinsicHash}) =>
      _answer<MultisigProposalApprovedEvent>();

  @override
  Future<MultisigProposalExecutedEvent?> searchExecutedByExtrinsicHash({required String extrinsicHash}) =>
      _answer<MultisigProposalExecutedEvent>();

  @override
  Future<MultisigProposalCancelledEvent?> searchCancelledByExtrinsicHash({required String extrinsicHash}) =>
      _answer<MultisigProposalCancelledEvent>();

  @override
  Future<MultisigProposalCreatedEvent?> searchProposalCreatedByExtrinsicHash({required String extrinsicHash}) =>
      _answer<MultisigProposalCreatedEvent>();

  @override
  Future<SortedTransactionsList> fetchAllTransactionTypes({
    required List<String> accountIds,
    int limit = 20,
    AccountEventCursor? otherAfter,
    AccountEventCursor? scheduledAfter,
    required TransactionFilter filter,
  }) async => SortedTransactionsList.empty;
}

typedef _Wallet = ({WalletTestBed bed, _Chain chain, _Indexer indexer, ProviderContainer container});

/// An approve, execute or cancel, sent from this device or signed off it.
class _Action {
  const _Action({
    required this.name,
    required this.word,
    required this.send,
    required this.sendSigned,
    required this.rows,
    required this.resolved,
    required this.event,
  });

  final String name;

  /// How the session's log names what it dropped.
  final String word;
  final Future<void> Function(ProviderContainer container, MultisigProposal proposal) send;
  final Future<String> Function(ProviderContainer container, MultisigProposal proposal) sendSigned;
  final List<String?> Function(ProviderContainer container) rows;

  /// The proposal once the chain shows this action.
  final MultisigProposal Function() resolved;
  final TransactionEvent Function() event;
}

TransactionSubmissionService _service(ProviderContainer container) =>
    container.read(transactionSubmissionServiceProvider);

final _approve = _Action(
  name: 'an approval',
  word: 'approval',
  send: (c, p) => _service(c).approveProposal(msig: _msig, signer: _member, proposal: p),
  sendSigned: (c, p) => _service(c).approveProposalWithExternalSignature(
    msig: _msig,
    signer: _member,
    proposal: p,
    unsignedData: _Unsigned(),
    signatureWithPublicKey: Uint8List(1),
  ),
  rows: (c) => c.read(pendingMultisigApprovalsProvider).map((row) => row.extrinsicHash).toList(),
  resolved: () => _proposal(MultisigProposalStatus.active, approvals: [_member.accountId]),
  event: () => MultisigProposalApprovedEvent(
    id: 'indexed-action',
    approverId: _member.accountId,
    multisigAddress: _msig.accountId,
    recipient: 'qzTo',
    amount: BigInt.one,
    proposalId: 7,
    approvalsCount: 1,
    timestamp: DateTime.utc(2026),
    blockNumber: 2,
    blockHash: '0xblock',
  ),
);

final _execute = _Action(
  name: 'an execution',
  word: 'execution',
  send: (c, p) => _service(c).executeProposal(msig: _msig, signer: _member, proposal: p),
  sendSigned: (c, p) => _service(c).executeProposalWithExternalSignature(
    msig: _msig,
    signer: _member,
    proposal: p,
    unsignedData: _Unsigned(),
    signatureWithPublicKey: Uint8List(1),
  ),
  rows: (c) => c.read(pendingMultisigExecutionsProvider).map((row) => row.extrinsicHash).toList(),
  resolved: () => _proposal(MultisigProposalStatus.executed),
  event: () => MultisigProposalExecutedEvent(
    id: 'indexed-action',
    executorId: _member.accountId,
    multisigAddress: _msig.accountId,
    recipient: 'qzTo',
    amount: BigInt.one,
    proposalId: 7,
    approvers: [_member.accountId],
    result: 'success',
    timestamp: DateTime.utc(2026),
    blockNumber: 2,
    blockHash: '0xblock',
  ),
);

final _cancel = _Action(
  name: 'a cancellation',
  word: 'cancellation',
  send: (c, p) => _service(c).cancelProposal(msig: _msig, proposer: _member, proposal: p),
  sendSigned: (c, p) => _service(c).cancelProposalWithExternalSignature(
    msig: _msig,
    proposer: _member,
    proposal: p,
    unsignedData: _Unsigned(),
    signatureWithPublicKey: Uint8List(1),
  ),
  rows: (c) => c.read(pendingMultisigCancellationsProvider).map((row) => row.extrinsicHash).toList(),
  resolved: () => _proposal(MultisigProposalStatus.cancelled),
  event: () => MultisigProposalCancelledEvent(
    id: 'indexed-action',
    proposerId: _member.accountId,
    multisigAddress: _msig.accountId,
    recipient: 'qzTo',
    amount: BigInt.one,
    proposalId: 7,
    timestamp: DateTime.utc(2026),
    blockNumber: 2,
    blockHash: '0xblock',
  ),
);

final _actions = [_approve, _execute, _cancel];

/// What the pollers watch for: an action, or a proposal being created.
class _Watched {
  const _Watched({
    required this.name,
    required this.word,
    required this.track,
    required this.rows,
    required this.event,
    this.action,
  });

  final String name;
  final String word;
  final Future<void> Function(_Wallet wallet) track;
  final List<String?> Function(ProviderContainer container) rows;
  final TransactionEvent Function() event;

  /// Null for a proposal, whose search reads the indexer alone.
  final _Action? action;
}

_Watched _watchedAction(_Action action) => _Watched(
  name: action.name,
  word: action.word,
  action: action,
  rows: action.rows,
  event: action.event,
  track: (wallet) async {
    final sent = action.send(wallet.container, _proposal(MultisigProposalStatus.active));
    wallet.chain.accepted.complete(Uint8List.fromList([1]));
    await sent;
  },
);

final _watchedProposal = _Watched(
  name: 'a proposal',
  word: 'proposal',
  rows: (c) => c.read(pendingMultisigProposalsProvider).map((row) => row.extrinsicHash).toList(),
  event: () => MultisigProposalCreatedEvent(
    id: 'indexed-action',
    proposerId: _member.accountId,
    multisigAddress: _msig.accountId,
    recipient: 'qzTo',
    amount: BigInt.one,
    palletFee: BigInt.zero,
    deposit: BigInt.zero,
    timestamp: DateTime.utc(2026),
    blockNumber: 2,
    blockHash: '0xblock',
    extrinsicHash: _proposalHash,
  ),
  track: (wallet) async {
    final pending = PendingMultisigProposalEvent.create(
      msig: _msig,
      proposerId: _member.accountId,
      recipient: 'qzTo',
      amount: BigInt.one,
      expiryBlock: 100,
    ).copyWith(extrinsicHash: _proposalHash);
    wallet.container.read(pendingMultisigProposalsProvider.notifier).add(pending);
    wallet.container.read(multisigProposalPollingServiceProvider).startPolling(_msig, pending);
  },
);

final _allWatched = [..._actions.map(_watchedAction), _watchedProposal];

Future<_Wallet> _wallet(WidgetTester tester) async {
  final bed = WalletTestBed();
  final chain = _Chain();
  final indexer = _Indexer();
  final container = ProviderContainer(
    overrides: [
      ...bed.overrides,
      multisigServiceProvider.overrideWithValue(chain),
      chainHistoryServiceProvider.overrideWithValue(indexer),
      balanceProviderFamily.overrideWith((ref, accountId) async {
        chain.balanceReads++;
        return BigInt.one;
      }),
    ],
  );
  container.listen(balanceProviderFamily(_member.accountId), (_, _) {});
  container.read(notificationProvider);
  await tester.pump();
  return (bed: bed, chain: chain, indexer: indexer, container: container);
}

/// Runs what is queued. A zero duration, as a bare pump leaves the rebuild of
/// an invalidated provider waiting on its timer.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(Duration.zero);
  }
}

/// The member's history, by event id. Read once before an event can land, or
/// nothing is there to receive it.
List<String> _history(ProviderContainer container) => container
    .read(
      filteredPaginationControllerProviderFamily(
        FilteredTransactionsParams(
          accountIds: AccountIdListCache.get([_member.accountId]),
          filter: TransactionFilter.all,
        ),
      ),
    )
    .otherTransfers
    .map((event) => event.id)
    .toList();

SendConfirmation _proposalOutcome(ProviderContainer container) =>
    container.read(multisigProposalConfirmationProvider(_proposalHash));

Future<void> _close(WidgetTester tester, _Wallet wallet) async {
  await tester.pump();
  wallet.container.dispose();
}

/// A wipe under way that waits for the test, and fails if [fails].
Future<({Future<void> logout, Completer<void> wipe})> _wiping(
  WidgetTester tester,
  _Wallet wallet, {
  required bool fails,
}) async {
  final wipe = wallet.bed.substrate.holdWipe = Completer<void>();
  if (fails) wallet.bed.substrate.logoutError = StateError('the wipe failed');
  final logout = wallet.container.read(logoutServiceProvider).logout();
  await tester.pump();
  return (logout: logout, wipe: wipe);
}

Future<void> _endFailedWipe(WidgetTester tester, ({Future<void> logout, Completer<void> wipe}) wiping) async {
  wiping.wipe.complete();
  await expectLater(wiping.logout, throwsStateError);
  await _settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('a multisig action going out', () {
    for (final action in _actions) {
      for (final keystone in [false, true]) {
        final how = keystone ? 'signed on a Keystone' : 'signed here';

        /// Sends it, its broadcast answering when `chain.accepted` completes.
        Future<String?> send(_Wallet wallet) {
          final proposal = _proposal(MultisigProposalStatus.active);
          if (!keystone) return action.send(wallet.container, proposal).then((_) => null);
          wallet.bed.substrate.holdExternalBroadcast = wallet.chain.accepted;
          return action.sendSigned(wallet.container, proposal);
        }

        Future<void> expectItsAnswer(Future<String?> sent) async {
          // Only the Keystone path returns the hash to its caller.
          expect(await sent, keystone ? _hash : isNull);
        }

        testWidgets('${action.name} $how answering after a reset is not tracked', (tester) async {
          final wallet = await _wallet(tester);
          final sent = send(wallet);

          await wallet.container.read(logoutServiceProvider).logout();
          await tester.pump();
          wallet.chain.accepted.complete(Uint8List.fromList([1]));
          await expectItsAnswer(sent);
          await tester.pump(const Duration(seconds: 6));
          await tester.pump();

          expect(action.rows(wallet.container), isEmpty);
          expect(wallet.chain.reads, 0);
          expect(wallet.bed.droppedByReset, contains(contains(_hash)));
          await _close(tester, wallet);
        });

        testWidgets('${action.name} $how answering during a wipe that fails leaves no row stuck', (tester) async {
          final wallet = await _wallet(tester);
          final sent = send(wallet);
          final wiping = await _wiping(tester, wallet, fails: true);

          wallet.chain.accepted.complete(Uint8List.fromList([1]));
          await expectItsAnswer(sent);
          await _endFailedWipe(tester, wiping);
          await tester.pump(const Duration(seconds: 6));
          await tester.pump();

          expect(action.rows(wallet.container), isEmpty);
          expect(wallet.chain.reads, 0);
          await _close(tester, wallet);
        });

        testWidgets('${action.name} $how with no reset is tracked', (tester) async {
          final wallet = await _wallet(tester);
          final sent = send(wallet);

          wallet.chain.accepted.complete(Uint8List.fromList([1]));
          await expectItsAnswer(sent);
          await tester.pump();

          expect(action.rows(wallet.container), [_hash]);
          expect(wallet.chain.reads, 1);
          await _close(tester, wallet);
        });

        testWidgets('${action.name} $how started after a reset is tracked', (tester) async {
          final wallet = await _wallet(tester);
          await wallet.container.read(logoutServiceProvider).logout();
          wallet.container.read(notificationProvider);
          await tester.pump();
          final sent = send(wallet);

          wallet.chain.accepted.complete(Uint8List.fromList([1]));
          await expectItsAnswer(sent);
          await tester.pump();

          expect(action.rows(wallet.container), [_hash]);
          expect(wallet.chain.reads, 1);
          await _close(tester, wallet);
        });
      }
    }
  });

  group('a search in flight at a reset', () {
    for (final watched in _allWatched) {
      /// Tracked, its first search waiting on the indexer, which has it.
      Future<_Wallet> searching(WidgetTester tester) async {
        final wallet = await _wallet(tester);
        wallet.chain.proposal = watched.action?.resolved();
        wallet.indexer.event = watched.event();
        wallet.indexer.holdSearch = 1;
        await watched.track(wallet);
        await tester.pump();
        _history(wallet.container);
        await tester.pump();
        return wallet;
      }

      testWidgets('for ${watched.name} adds nothing to the next wallet', (tester) async {
        final wallet = await searching(tester);

        await wallet.container.read(logoutServiceProvider).logout();
        await tester.pump();
        _history(wallet.container);
        await tester.pump();
        wallet.indexer.heldSearch.complete();
        await _settle(tester);

        expect(_history(wallet.container), isEmpty);
        expect(wallet.container.read(globalToastProvider), isNull);
        expect(_proposalOutcome(wallet.container), SendConfirmation.pending);
        expect(wallet.bed.droppedByReset, contains(contains(watched.word)));
        await _close(tester, wallet);
      });

      testWidgets('for ${watched.name} confirms once a wipe has failed', (tester) async {
        final wallet = await searching(tester);
        final wiping = await _wiping(tester, wallet, fails: true);

        wallet.indexer.heldSearch.complete();
        await _settle(tester);
        expect(watched.rows(wallet.container), hasLength(1), reason: 'nothing happens while the wipe runs');
        expect(_history(wallet.container), isEmpty);

        await _endFailedWipe(tester, wiping);

        expect(watched.rows(wallet.container), isEmpty);
        expect(_history(wallet.container), [watched.event().id]);
        if (watched.action == null) expect(_proposalOutcome(wallet.container), SendConfirmation.confirmed);
        await _close(tester, wallet);
      });
    }
  });

  group('the final check at the end of the watch', () {
    const lastOrdinarySearch = Duration(minutes: 5, seconds: 2);
    const theTimeout = Duration(seconds: 5);

    for (final watched in _allWatched) {
      /// Past the watch, its final check held. The chain and indexer have
      /// nothing of it.
      Future<({_Wallet wallet, void Function() release})> atTheFinalCheck(WidgetTester tester) async {
        final wallet = await _wallet(tester);
        await watched.track(wallet);
        await tester.pump(lastOrdinarySearch);
        final void Function() release;
        if (watched.action == null) {
          wallet.indexer.holdSearch = wallet.indexer.searches + 1;
          release = wallet.indexer.heldSearch.complete;
        } else {
          wallet.chain.holdRead = wallet.chain.reads + 1;
          release = wallet.chain.heldRead.complete;
        }
        await tester.pump(theTimeout);
        return (wallet: wallet, release: release);
      }

      testWidgets('of ${watched.name} giving up during a wipe that goes through says nothing', (tester) async {
        final (:wallet, :release) = await atTheFinalCheck(tester);
        final wiping = await _wiping(tester, wallet, fails: false);

        release();
        await _settle(tester);
        expect(wallet.container.read(globalToastProvider), isNull);
        expect(_proposalOutcome(wallet.container), SendConfirmation.pending);

        wiping.wipe.complete();
        await wiping.logout;
        await _settle(tester);

        expect(wallet.container.read(globalToastProvider), isNull);
        expect(_proposalOutcome(wallet.container), SendConfirmation.pending);
        await _close(tester, wallet);
      });

      testWidgets('of ${watched.name} giving up during a wipe that fails says so after it', (tester) async {
        final (:wallet, :release) = await atTheFinalCheck(tester);
        final wiping = await _wiping(tester, wallet, fails: true);

        release();
        await _settle(tester);
        expect(wallet.container.read(globalToastProvider), isNull);
        expect(watched.rows(wallet.container), hasLength(1));

        await _endFailedWipe(tester, wiping);

        expect(wallet.container.read(globalToastProvider)?.type, ToastType.error);
        expect(watched.rows(wallet.container), isEmpty);
        if (watched.action == null) expect(_proposalOutcome(wallet.container), SendConfirmation.unconfirmed);
        await _close(tester, wallet);
      });
    }

    group('resolving from the chain', () {
      /// Past the watch: the chain now shows [action], the indexer does not
      /// yet, and the timeout's own read or search is held.
      Future<({_Wallet wallet, void Function() release})> resolving(
        WidgetTester tester,
        _Action action, {
        required bool heldAtSearch,
      }) async {
        final wallet = await _wallet(tester);
        await _watchedAction(action).track(wallet);
        await tester.pump(lastOrdinarySearch);
        wallet.chain.proposal = action.resolved();
        final void Function() release;
        if (heldAtSearch) {
          // The final check searches once, the resolve next.
          wallet.indexer.holdSearch = wallet.indexer.searches + 2;
          release = wallet.indexer.heldSearch.complete;
        } else {
          // The final check reads once, the resolve next.
          wallet.chain.holdRead = wallet.chain.reads + 2;
          release = wallet.chain.heldRead.complete;
        }
        await tester.pump(theTimeout);
        await _settle(tester);
        _history(wallet.container);
        await tester.pump();
        return (wallet: wallet, release: release);
      }

      for (final action in _actions) {
        for (final (stage, heldAtSearch) in [('reading the proposal', false), ('searching the indexer', true)]) {
          testWidgets('${action.name} $stage when a reset goes through writes nothing', (tester) async {
            final (:wallet, :release) = await resolving(tester, action, heldAtSearch: heldAtSearch);

            await wallet.container.read(logoutServiceProvider).logout();
            await tester.pump();
            _history(wallet.container);
            await tester.pump();
            wallet.indexer.event = action.event();
            release();
            await _settle(tester);

            expect(_history(wallet.container), isEmpty);
            expect(wallet.container.read(globalToastProvider), isNull);
            expect(wallet.bed.droppedByReset, contains(contains(action.word)));
            await _close(tester, wallet);
          });

          testWidgets('${action.name} $stage when a wipe fails resolves after it', (tester) async {
            final (:wallet, :release) = await resolving(tester, action, heldAtSearch: heldAtSearch);
            final wiping = await _wiping(tester, wallet, fails: true);

            wallet.indexer.event = action.event();
            release();
            await _settle(tester);
            expect(_history(wallet.container), isEmpty);
            // Past the read, the row is already gone, before the wipe began.
            if (!heldAtSearch) expect(action.rows(wallet.container), hasLength(1));

            await _endFailedWipe(tester, wiping);

            expect(action.rows(wallet.container), isEmpty);
            expect(_history(wallet.container), [action.event().id]);
            await _close(tester, wallet);
          });
        }
      }

      for (final action in _actions) {
        for (final (answer, fails) in [('finds nothing', false), ('fails', true)]) {
          testWidgets('${action.name} whose search $answer at a reset shows no toast, reads no balance', (
            tester,
          ) async {
            final (:wallet, :release) = await resolving(tester, action, heldAtSearch: true);
            wallet.indexer.failHeldSearch = fails;
            final balanceReads = wallet.chain.balanceReads;

            await wallet.container.read(logoutServiceProvider).logout();
            await tester.pump();
            release();
            await _settle(tester);

            expect(wallet.container.read(globalToastProvider), isNull);
            expect(wallet.chain.balanceReads, balanceReads);
            await _close(tester, wallet);
          });
        }

        testWidgets('with no reset, ${action.name} the indexer has not seen refreshes the balance', (tester) async {
          final (:wallet, :release) = await resolving(tester, action, heldAtSearch: true);
          final balanceReads = wallet.chain.balanceReads;

          release();
          await _settle(tester);

          expect(wallet.chain.balanceReads, greaterThan(balanceReads));
          expect(action.rows(wallet.container), isEmpty);
          await _close(tester, wallet);
        });
      }

      testWidgets('with no reset, an execution by another signer still says so', (tester) async {
        final (:wallet, :release) = await resolving(tester, _execute, heldAtSearch: true);

        release();
        await _settle(tester);

        expect(wallet.container.read(globalToastProvider)?.type, ToastType.info);
        expect(_execute.rows(wallet.container), isEmpty);
        await _close(tester, wallet);
      });
    });
  });
}
