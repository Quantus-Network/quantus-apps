import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/mainnet/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';

/// The `where:` argument of the first `account_event` selection in [query].
String _whereClause(String query) {
  final start = query.indexOf('where:');
  final end = query.indexOf('order_by:', start);
  expect(start, isNonNegative, reason: 'query has a where clause');
  expect(end, greaterThan(start), reason: 'query has an order_by after where');
  return query.substring(start, end);
}

void main() {
  final service = ChainHistoryService();

  group('account_event queries', () {
    const withoutCursor = false;
    final all = ChainHistoryService.buildAccountEventsQuery(
      TransactionFilter.all,
      withCursor: withoutCursor,
      accountCount: 1,
    );
    final send = ChainHistoryService.buildAccountEventsQuery(
      TransactionFilter.send,
      withCursor: withoutCursor,
      accountCount: 1,
    );
    final receive = ChainHistoryService.buildAccountEventsQuery(
      TransactionFilter.receive,
      withCursor: withoutCursor,
      accountCount: 1,
    );

    test('send and receive filter on the indexed direction columns', () {
      expect(_whereClause(send), contains('outgoing: {_eq: true}'));
      expect(_whereClause(send), isNot(contains('incoming')));
      expect(_whereClause(receive), contains('incoming: {_eq: true}'));
      expect(_whereClause(receive), isNot(contains('outgoing')));
      expect(_whereClause(all), isNot(contains('outgoing')));
      expect(_whereClause(all), isNot(contains('incoming')));
    });

    test('no variant filters through nested relations, _or, _in, or an extrinsic guard', () {
      for (final query in [all, send, receive]) {
        final where = _whereClause(query);
        expect(where, isNot(contains('_or')), reason: 'nested OR defeats the (account_id, ..., timestamp, id) index');
        expect(where, isNot(contains('transfer: {')));
        expect(where, isNot(contains('executedReversibleTransfer: {')));
        expect(where, isNot(contains('cancelledReversibleTransfer: {')));
        expect(where, isNot(contains('extrinsic_id')), reason: 'extrinsic-less transfers are no longer indexed rows');
        expect(
          where,
          contains(r'account_id: {_eq: $account0}'),
          reason: '`_in` renders as `= ANY(array)`, which the planner would not walk on the composite index',
        );
        expect(where, isNot(contains('_in')));
        expect(where, contains('scheduled_reversible_transfer_id: {_is_null: true}'));
      }
    });

    test('order_by leads with the composite index columns so Postgres never falls back to the timestamp index', () {
      // Live Planck EXPLAIN: with only (timestamp, id) in ORDER BY the planner
      // walked the global timestamp index backwards through 1.6M rows to find
      // 0 incoming rows for a send-only account (14s); leading with the index
      // prefix turned that into a 4ms index scan.
      expect(all, contains('order_by: [{account_id: desc}, {timestamp: desc}, {id: desc}]'));
      expect(send, contains('order_by: [{account_id: desc}, {outgoing: desc}, {timestamp: desc}, {id: desc}]'));
      expect(receive, contains('order_by: [{account_id: desc}, {incoming: desc}, {timestamp: desc}, {id: desc}]'));
    });

    test('one aliased selection per account, each on its own _eq variable', () {
      final twoAccounts = ChainHistoryService.buildAccountEventsQuery(
        TransactionFilter.all,
        withCursor: false,
        accountCount: 2,
      );

      expect(twoAccounts, contains(r'$account0: String!'));
      expect(twoAccounts, contains(r'$account1: String!'));
      expect(twoAccounts, contains('events0: account_event('));
      expect(twoAccounts, contains('events1: account_event('));
      expect(twoAccounts, contains(r'account_id: {_eq: $account0}'));
      expect(twoAccounts, contains(r'account_id: {_eq: $account1}'));
      expect(twoAccounts, isNot(contains('events2:')));
    });

    test('pages by (timestamp, id) keyset instead of OFFSET', () {
      for (final query in [all, send, receive]) {
        expect(query, isNot(contains('offset')));
        expect(query, isNot(contains(r'$cursorTimestamp')), reason: 'first page has no cursor');
      }

      final afterCursor = ChainHistoryService.buildAccountEventsQuery(
        TransactionFilter.all,
        withCursor: true,
        accountCount: 1,
      );
      expect(afterCursor, contains(r'$cursorTimestamp: timestamptz!'));
      expect(afterCursor, contains(r'$cursorId: String!'));
      expect(_whereClause(afterCursor), contains(r'timestamp: {_lte: $cursorTimestamp}'));
      expect(_whereClause(afterCursor), contains(r'_not: {timestamp: {_eq: $cursorTimestamp}, id: {_gte: $cursorId}}'));
    });

    test('page variables bind one account per alias', () {
      final variables = ChainHistoryService.pageVariables(
        accountIds: const ['qz-a', 'qz-b'],
        lookaheadLimit: 21,
        after: const AccountEventCursor(timestamp: 't1', id: 'x'),
      );

      expect(variables, {
        'account0': 'qz-a',
        'account1': 'qz-b',
        'limit': 21,
        'cursorTimestamp': 't1',
        'cursorId': 'x',
      });
    });

    test('pending search declares amount as Hasura numeric, not BigInt', () {
      for (final query in [
        ChainHistoryService.searchPendingTransferQuery,
        ChainHistoryService.searchPendingReversibleQuery,
      ]) {
        expect(query, contains(r'$amount: numeric!'));
        expect(query, isNot(contains('BigInt')));
      }
    });

    test('scheduled reversible query uses the same per-account shape, direction columns and keyset', () {
      final scheduledSend = ChainHistoryService.buildScheduledReversibleTransfersQuery(
        TransactionFilter.send,
        withCursor: false,
        accountCount: 1,
      );
      final scheduledAfter = ChainHistoryService.buildScheduledReversibleTransfersQuery(
        TransactionFilter.receive,
        withCursor: true,
        accountCount: 2,
      );

      expect(_whereClause(scheduledSend), contains(r'account_id: {_eq: $account0}'));
      expect(_whereClause(scheduledSend), contains('outgoing: {_eq: true}'));
      expect(_whereClause(scheduledSend), isNot(contains('from_id')));
      expect(_whereClause(scheduledSend), contains(r'scheduledReversibleTransfer: {scheduled_at: {_gt: $after}}'));
      expect(scheduledSend, isNot(contains('offset')));
      expect(
        scheduledSend,
        contains('order_by: [{account_id: desc}, {outgoing: desc}, {timestamp: desc}, {id: desc}]'),
      );
      expect(scheduledAfter, contains('events1: account_event('));
      expect(_whereClause(scheduledAfter), contains('incoming: {_eq: true}'));
      expect(_whereClause(scheduledAfter), contains(r'timestamp: {_lte: $cursorTimestamp}'));
      expect(
        _whereClause(scheduledAfter),
        contains(r'_not: {timestamp: {_eq: $cursorTimestamp}, id: {_gte: $cursorId}}'),
      );
    });
  });

  group('mergeAccountEventRows', () {
    Map<String, dynamic> row(String id, String timestamp) => {'id': id, 'timestamp': timestamp};

    test('interleaves per-account aliases into one (timestamp desc, id desc) stream', () {
      final data = <String, dynamic>{
        'events0': [row('a2', '2026-06-02T00:00:00.000+00:00'), row('a1', '2026-06-01T00:00:00.000+00:00')],
        'events1': [
          row('b3', '2026-06-03T00:00:00.000+00:00'),
          row('b2', '2026-06-02T00:00:00.000+00:00'),
          row('b0', '2026-05-31T00:00:00.000+00:00'),
        ],
      };

      final merged = ChainHistoryService.mergeAccountEventRows(data, accountCount: 2);

      expect(merged.map((r) => (r as Map<String, dynamic>)['id']).toList(), ['b3', 'b2', 'a2', 'a1', 'b0']);
    });

    test('compares timestamps as instants, not strings', () {
      final data = <String, dynamic>{
        'events0': [row('short', '2026-06-01T00:00:00.5+00:00')],
        'events1': [row('long', '2026-06-01T00:00:00.123456+00:00')],
      };

      final merged = ChainHistoryService.mergeAccountEventRows(data, accountCount: 2);

      expect(merged.map((r) => (r as Map<String, dynamic>)['id']).toList(), ['short', 'long']);
    });

    test('throws when an alias is missing from the response', () {
      expect(
        () => ChainHistoryService.mergeAccountEventRows(<String, dynamic>{'events0': <dynamic>[]}, accountCount: 2),
        throwsStateError,
      );
    });
  });

  group('pageFromRows', () {
    Map<String, dynamic> row(String id, String timestamp) => {'id': id, 'timestamp': timestamp};
    String? parseId(dynamic row) {
      final id = (row as Map<String, dynamic>)['id'] as String;
      return id.startsWith('skip') ? null : id;
    }

    test('advances the cursor to the last consumed raw row, even one that parsed to null', () {
      final rows = [row('a', 't2'), row('skip-b', 't1'), row('c', 't1')];

      final page = ChainHistoryService.pageFromRows(rows, 2, parseId, previousCursor: null);

      expect(page.items, ['a']);
      expect(page.hasMore, isTrue, reason: 'a lookahead row was returned');
      expect(page.nextCursor?.timestamp, 't1');
      expect(page.nextCursor?.id, 'skip-b');
    });

    test('keeps the previous cursor when the page is empty', () {
      const previous = AccountEventCursor(timestamp: 't9', id: 'z');

      final page = ChainHistoryService.pageFromRows(<dynamic>[], 2, parseId, previousCursor: previous);

      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, same(previous));
    });

    test('a short page has no more and points at its last row', () {
      final page = ChainHistoryService.pageFromRows([row('a', 't2')], 2, parseId, previousCursor: null);

      expect(page.hasMore, isFalse);
      expect(page.nextCursor?.id, 'a');
    });
  });

  const accountEventFixture = {
    'id':
        'ae-multisig-qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH-qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
    'timestamp': '2026-06-02T05:15:08.147+00:00',
    'multisig': {
      'id': 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH',
      'threshold': 2,
      'nonce': '0',
      'signers': [
        'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
        'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
        'qzntBpmqHZF1jxC8KJKpuxcYuHST892jyXBqRctpAxd1WQ9BL',
      ],
      'fee': '8120809264',
      'creator': {'id': 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7'},
      'timestamp': '2026-06-02T05:15:08.147+00:00',
      'block': {'height': 3, 'hash': '0xdfee413c921789a93b641c2eaf25be8c3d7770841cc7e83aff369cdd882eb9f4'},
      'extrinsic': {'id': '0xea4400ec3247fc75b7187b6f6d83a89905017d1136c894e625a3c43a688606b9'},
    },
  };

  const proposalCreatedAccountEventFixture = {
    'id': 'ae-ms-proposal-created-0000000256-c9dc5-000005-qzk1',
    'timestamp': '2026-06-03T10:00:00.000+00:00',
    'multisigProposalCreated': {
      'id': 'ms-proposal-created-256',
      'fee': '500000000000',
      'deposit': '10000000000000',
      'burned_pallet_fee': '1000000000',
      'timestamp': '2026-06-03T10:00:00.000+00:00',
      'block': {'height': 256, 'hash': '0xabc'},
      'extrinsic': {'id': '0xproposalhash'},
      'proposal': {
        'id': 'proposal-entity-1',
        'proposal_id': 5,
        'created_at': '2026-06-03T10:00:00.000+00:00',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x',
        'transfer_amount': '2000000000000',
        'status': 'active',
        'expiry_block': 1000,
        'deposit': '10000000000000',
        'approvals': [],
        'proposer': {'id': 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7'},
        'transferTo': {'id': 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda'},
        'multisig': {
          'id': 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH',
          'threshold': 2,
          'nonce': '0',
          'signers': [
            'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
            'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
          ],
        },
      },
    },
  };

  const liveProposalCreatedFixture = {
    'id': 'ae-ms-proposal-created-0000000041-ffb25-000005-qznKte8yHbpFssBG3SbTtHyQMZEpcbaXcYVZWfTSM1L5i7Kak',
    'timestamp': '2026-06-05T06:09:29.445+00:00',
    'multisigProposalCreated': {
      'id': '0000000041-ffb25-000005',
      'fee': '8118976792',
      'deposit': '1000000000000',
      'burned_pallet_fee': '1020000000000',
      'timestamp': '2026-06-05T06:09:29.445+00:00',
      'block': {'height': 41, 'hash': '0xffb255d42a1f272f8ae7cb9f3acc6001f8eaaf93358273fb4955645774fa4e17'},
      'extrinsic': {'id': '0xbc2035c2d62d481bcef2f00d0f284a0485caa5c21945b62f1d9bbfb749d8c9ae'},
      'proposal': {
        'id': 'qzo9WMB71LeLXsR5WRj7PGdUUGJHq9Qr7VmEXqnRiCWKvjWtE-0',
        'proposal_id': 0,
        'created_at': '2026-06-05T06:09:29.445+00:00',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0200007f1aaca9d332c0f96275e28bfcd50b9f704d86c7e26e64f46ced3fc6094e6ebf0b00a0724e1809',
        'transfer_amount': '10000000000000',
        'status': 'ACTIVE',
        'expiry_block': 14440,
        'deposit': '1000000000000',
        'approvals': ['qznKte8yHbpFssBG3SbTtHyQMZEpcbaXcYVZWfTSM1L5i7Kak'],
        'proposer': {'id': 'qznKte8yHbpFssBG3SbTtHyQMZEpcbaXcYVZWfTSM1L5i7Kak'},
        'transferTo': {'id': 'qznKte8yHbpFssBG3SbTtHyQMZEpcbaXcYVZWfTSM1L5i7Kak'},
        'multisig': {'id': 'qzo9WMB71LeLXsR5WRj7PGdUUGJHq9Qr7VmEXqnRiCWKvjWtE'},
      },
    },
  };

  const signerApprovedAccountEventFixture = {
    'id': 'ae-ms-signer-approved-0000000256-c9dc5-000005-qzk2',
    'timestamp': '2026-06-03T11:00:00.000+00:00',
    'multisigSignerApproved': {
      'id': 'ms-signer-approved-256',
      'fee': '25000000000',
      'approvals_count': 2,
      'timestamp': '2026-06-03T11:00:00.000+00:00',
      'block': {'height': 257, 'hash': '0xdef'},
      'extrinsic': {'id': '0xapprovehash'},
      'approver': {'id': 'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y'},
      'proposal': {
        'id': 'proposal-entity-1',
        'proposal_id': 5,
        'created_at': '2026-06-03T10:00:00.000+00:00',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x',
        'transfer_amount': '2000000000000',
        'status': 'ACTIVE',
        'expiry_block': 1000,
        'deposit': '10000000000000',
        'approvals': [
          'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
          'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
        ],
        'proposer': {'id': 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7'},
        'transferTo': {'id': 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda'},
        'multisig': {
          'id': 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH',
          'threshold': 2,
          'nonce': '0',
          'signers': [
            'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
            'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
          ],
        },
      },
    },
  };

  const executedMultisigProposalAccountEventFixture = {
    'id': 'ae-ms-exec-0000000256-c9dc5-000005-qzk2',
    'timestamp': '2026-06-03T12:00:00.000+00:00',
    'executedMultisigProposal': {
      'id': 'ms-exec-256',
      'fee': '18000000000',
      'result': 'Ok',
      'approvers': [
        'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
        'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
      ],
      'timestamp': '2026-06-03T12:00:00.000+00:00',
      'block': {'height': 258, 'hash': '0xexec'},
      'extrinsic': {
        'id': '0xexecutehash',
        'signer': {'id': 'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y'},
      },
      'proposal': {
        'id': 'proposal-entity-1',
        'proposal_id': 5,
        'created_at': '2026-06-03T10:00:00.000+00:00',
        'updated_at': '2026-06-03T12:00:00.000+00:00',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x',
        'transfer_amount': '2000000000000',
        'status': 'EXECUTED',
        'expiry_block': 1000,
        'deposit': '10000000000000',
        'approvals': [
          'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
          'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
        ],
        'proposer': {'id': 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7'},
        'transferTo': {'id': 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda'},
        'multisig': {
          'id': 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH',
          'threshold': 2,
          'nonce': '0',
          'signers': [
            'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
            'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y',
          ],
        },
      },
    },
  };

  group('ChainHistoryService.tryParseOtherTransferEvent', () {
    test('returns null for unhandled multisig indexer account events', () {
      expect(service.tryParseOtherTransferEvent({'id': 'ae-ms-proposal-ready-0000000256-qzk1'}), isNull);
    });

    test('parses multisig proposal executed account events', () {
      final result = service.tryParseOtherTransferEvent(executedMultisigProposalAccountEventFixture);
      expect(result, isA<MultisigProposalExecutedEvent>());

      final event = result! as MultisigProposalExecutedEvent;
      expect(event.executorId, 'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y');
      expect(event.multisigAddress, 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH');
      expect(event.recipient, 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda');
      expect(event.amount, BigInt.parse('2000000000000'));
      expect(event.fee, BigInt.parse('18000000000'));
      expect(event.proposalId, 5);
      expect(event.approvers, hasLength(2));
      expect(event.result, 'Ok');
      expect(event.extrinsicHash, '0xexecutehash');
      expect(event.proposal, isNotNull);
    });

    test('parses multisig signer approved account events', () {
      final result = service.tryParseOtherTransferEvent(signerApprovedAccountEventFixture);
      expect(result, isA<MultisigProposalApprovedEvent>());

      final event = result! as MultisigProposalApprovedEvent;
      expect(event.approverId, 'qzkYEQv8tQsmniZYdame3Cku18RL5g9bGK9Pdydq5TMPdpE3y');
      expect(event.multisigAddress, 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH');
      expect(event.recipient, 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda');
      expect(event.amount, BigInt.parse('2000000000000'));
      expect(event.fee, BigInt.parse('25000000000'));
      expect(event.proposalId, 5);
      expect(event.approvalsCount, 2);
      expect(event.extrinsicHash, '0xapprovehash');
      expect(event.proposal, isNotNull);
      expect(event.proposal!.signerCount, 2);
      expect(event.proposal!.threshold, 2);
      expect(event.approvalsOfSignersLabel((c, t) => '$c of $t'), '2 of 2');
    });

    test('parses signer approved with sparse multisig without wrong threshold', () {
      final sparse = Map<String, dynamic>.from(signerApprovedAccountEventFixture);
      final approved = Map<String, dynamic>.from(sparse['multisigSignerApproved'] as Map<String, dynamic>);
      final proposal = Map<String, dynamic>.from(approved['proposal'] as Map<String, dynamic>);
      proposal['multisig'] = {'id': 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH'};
      approved['proposal'] = proposal;
      sparse['multisigSignerApproved'] = approved;

      final result = service.tryParseOtherTransferEvent(sparse);
      final event = result! as MultisigProposalApprovedEvent;
      expect(event.proposal!.signerCount, 0);
      expect(event.approvalsOfSignersLabel((c, t) => '$c of $t'), isNull);
    });

    test('parses live indexer proposal created shape with sparse multisig', () {
      final result = service.tryParseOtherTransferEvent(liveProposalCreatedFixture);
      expect(result, isA<MultisigProposalCreatedEvent>());

      final event = result! as MultisigProposalCreatedEvent;
      expect(event.amount, BigInt.parse('10000000000000'));
      expect(event.palletFee, BigInt.parse('1020000000000'));
      expect(event.fee, BigInt.parse('8118976792'));
    });

    test('parses multisig proposal created account events', () {
      final result = service.tryParseOtherTransferEvent(proposalCreatedAccountEventFixture);
      expect(result, isA<MultisigProposalCreatedEvent>());

      final event = result! as MultisigProposalCreatedEvent;
      expect(event.proposerId, 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7');
      expect(event.multisigAddress, 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH');
      expect(event.recipient, 'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda');
      expect(event.amount, BigInt.parse('2000000000000'));
      expect(event.palletFee, BigInt.parse('1000000000'));
      expect(event.deposit, BigInt.parse('10000000000000'));
      expect(event.fee, BigInt.parse('500000000000'));
      expect(event.extrinsicHash, '0xproposalhash');
      expect(event.proposal, isNotNull);
    });

    test('parses multisig account events', () {
      final result = service.tryParseOtherTransferEvent(accountEventFixture);
      expect(result, isA<MultisigCreatedEvent>());

      final event = result! as MultisigCreatedEvent;
      expect(event.creatorId, 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7');
      expect(event.multisigAddress, 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH');
      expect(event.threshold, 2);
      expect(event.signers, hasLength(3));
      expect(event.palletFee, multisig_pallet.Constants().multisigFee);
      expect(event.networkFee, BigInt.parse('8120809264'));
      expect(event.extrinsicHash, '0xea4400ec3247fc75b7187b6f6d83a89905017d1136c894e625a3c43a688606b9');
    });
  });

  group('MultisigCreatedEvent.fromMultisigGraphql', () {
    test('throws when threshold is missing or invalid', () {
      final base = Map<String, dynamic>.from(accountEventFixture['multisig'] as Map<String, dynamic>);

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(multisig: Map<String, dynamic>.from(base)..remove('threshold')),
        throwsFormatException,
      );

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(multisig: Map<String, dynamic>.from(base)..['threshold'] = 0),
        throwsFormatException,
      );
    });

    test('throws when signers are missing or empty', () {
      final base = Map<String, dynamic>.from(accountEventFixture['multisig'] as Map<String, dynamic>);

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(multisig: Map<String, dynamic>.from(base)..remove('signers')),
        throwsFormatException,
      );

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(multisig: Map<String, dynamic>.from(base)..['signers'] = []),
        throwsFormatException,
      );
    });

    test('parses string threshold from indexer', () {
      final base = Map<String, dynamic>.from(accountEventFixture['multisig'] as Map<String, dynamic>);
      final event = MultisigCreatedEvent.fromMultisigGraphql(
        multisig: Map<String, dynamic>.from(base)..['threshold'] = '2',
      );
      expect(event.threshold, 2);
    });

    test('parses network fee from GraphQL fee field', () {
      final base = Map<String, dynamic>.from(accountEventFixture['multisig'] as Map<String, dynamic>);
      final withFee = MultisigCreatedEvent.fromMultisigGraphql(
        multisig: Map<String, dynamic>.from(base)..['fee'] = '8120809264',
      );

      expect(withFee.palletFee, multisig_pallet.Constants().multisigFee);
      expect(withFee.networkFee, BigInt.parse('8120809264'));
      expect(withFee.totalCost, withFee.palletFee + withFee.networkFee);
    });
  });
}
