import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/services/multisig_graphql.dart';

const _kinds = MultisigProposalActivityKind.values;

final _team = MultisigAccount(
  name: 'Team',
  accountId: 'qzTeam',
  signers: const ['qzMain', 'qzOther', 'qzThird'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

final _club = MultisigAccount(
  name: 'Club',
  accountId: 'qzClub',
  signers: const ['qzMain', 'qzOther'],
  threshold: 2,
  nonce: BigInt.zero,
  myMemberAccountId: 'qzMain',
);

/// A cursor for every kind, at the row `at-<kind>` of ten o'clock.
MultisigProposalActivityCursor _cursor() => {
  for (final kind in _kinds) kind: AccountEventCursor(timestamp: '2026-11-24T10:00:00+00:00', id: 'at-${kind.name}'),
};

/// Team's proposal 4, to send 1000 to Bob, proposed by Other in `0xcreated`.
Map<String, dynamic> _proposal() => {
  'id': 'qzTeam-4',
  'proposal_id': 4,
  'created_at': '2026-11-24T09:00:00.000Z',
  'updated_at': '2026-11-24T09:30:00.000Z',
  'pallet': 'Balances',
  'call': 'transfer_allow_death',
  'call_raw': null,
  'transfer_amount': '1000',
  'status': 'ACTIVE',
  'expiry_block': 500,
  'deposit': '10',
  'burned_pallet_fee': '1',
  'creation_network_fee': '2',
  'approvals': ['qzOther'],
  'decode_error': null,
  'proposer': {'id': 'qzOther'},
  'transferTo': {'id': 'qzBob'},
  'multisig': {
    'id': 'qzTeam',
    'threshold': 2,
    'signers': ['qzMain', 'qzOther', 'qzThird'],
    'nonce': '0',
  },
  'createdAtBlock': {'height': 7, 'hash': '0xblock'},
  'createdExtrinsic': {'id': '0xcreated'},
};

Map<String, dynamic> _row(String id, String timestamp, [Map<String, dynamic> more = const {}]) => {
  'id': id,
  'timestamp': timestamp,
  'proposal': _proposal(),
  ...more,
};

/// An answer with nothing in it for [multisigCount] multisigs.
Map<String, dynamic> _nothing(int multisigCount) => {
  for (var i = 0; i < multisigCount; i++)
    for (final kind in _kinds) 'm${i}_${kind.name}': <dynamic>[],
};

void main() {
  group('the query for what happened to multisigs\' proposals', () {
    test('asks a multisig never read only where each kind of event ends for it', () {
      final query = MultisigProposalActivityGraphql.buildSinceQuery(withCursor: [false]);

      expect(query, contains(r'query MultisigProposalActivitySince($multisig0: String!)'));
      for (final kind in _kinds) {
        expect(
          query,
          contains(
            'm0_${kind.name}: ${kind.table}(limit: 1, '
            r'where: {proposal: {multisig_id: {_eq: $multisig0}}}, '
            'order_by: [{timestamp: desc}, {id: desc}])',
          ),
          reason: kind.name,
        );
      }
      expect(query, isNot(contains('call_raw')), reason: 'no proposal is read for a starting point');
      expect(query, isNot(contains(r'$limit')));
    });

    test('reads a multisig read before on from its cursor of each kind, oldest first', () {
      final query = MultisigProposalActivityGraphql.buildSinceQuery(withCursor: [true]);

      expect(query, contains(r'$multisig0: String!, $ts0_created: timestamptz!, $id0_created: String!, '));
      expect(query, endsWith('}\n'));
      expect(query, contains(r'$ts0_removed: timestamptz!, $id0_removed: String!, $limit: Int!)'));
      for (final kind in _kinds) {
        final name = kind.name;
        expect(
          query,
          contains(
            'm0_$name: ${kind.table}(limit: \$limit, '
            'where: {_and: [{proposal: {multisig_id: {_eq: \$multisig0}}}, '
            '{timestamp: {_gte: \$ts0_$name}}, {_not: {timestamp: {_eq: \$ts0_$name}, id: {_lte: \$id0_$name}}}]}, '
            'order_by: [{timestamp: asc}, {id: asc}])',
          ),
          reason: name,
        );
      }
      expect(query, contains('createdExtrinsic'), reason: 'what a click finds the proposal by');
      expect(query, contains('approver {'));
      expect(query, contains('cancelledBy {'));
      expect(query, contains('removedBy {'));
      expect(query, contains('result'));
      expect('approvals_count'.allMatches(query), hasLength(2), reason: 'of a signature and of the last one');
      expect('signer {'.allMatches(query), hasLength(2), reason: 'who made it ready, and who executed it');
    });

    test('gives each multisig its own selections', () {
      final query = MultisigProposalActivityGraphql.buildSinceQuery(withCursor: [false, true]);

      expect(query, contains('m0_signed: multisig_signer_approved(limit: 1,'));
      expect(query, contains(r'm1_signed: multisig_signer_approved(limit: $limit,'));
      expect(query, contains(r'{proposal: {multisig_id: {_eq: $multisig1}}}'));
      expect(query, isNot(contains(r'$ts0_')));
    });

    test('is given the variables it declares, and no others', () {
      final variables = MultisigProposalActivityGraphql.sinceVariables({
        'qzTeam': null,
        'qzClub': _cursor(),
      }, limit: 50);

      expect(variables, {
        'multisig0': 'qzTeam',
        'multisig1': 'qzClub',
        for (final kind in _kinds) ...{
          'ts1_${kind.name}': '2026-11-24T10:00:00+00:00',
          'id1_${kind.name}': 'at-${kind.name}',
        },
        'limit': 50,
      });
      expect(MultisigProposalActivityGraphql.sinceVariables({'qzTeam': null}, limit: 50), {'multisig0': 'qzTeam'});
    });

    test('with no multisig to ask about is a mistake, not an empty answer', () {
      expect(() => MultisigProposalActivityGraphql.buildSinceQuery(withCursor: []), throwsArgumentError);
      expect(() => MultisigProposalActivityGraphql.sinceVariables({}, limit: 50), throwsArgumentError);
    });
  });

  group('the answer about what happened to multisigs\' proposals', () {
    test('to a first read is nothing, from where each kind ends, or from before any event', () {
      final read = MultisigProposalActivityGraphql.sinceOf(
        {
          ..._nothing(1),
          'm0_signed': [
            {'id': 'signed-9', 'timestamp': '2026-11-24T11:00:00+00:00'},
          ],
        },
        [_team],
        {'qzTeam': null},
      );

      expect(read.keys, ['qzTeam']);
      expect(read['qzTeam']!.activity, isEmpty);
      final cursor = read['qzTeam']!.cursor;
      expect(cursor.keys, unorderedEquals(_kinds));
      expect(
        (cursor[MultisigProposalActivityKind.signed]!.timestamp, cursor[MultisigProposalActivityKind.signed]!.id),
        ('2026-11-24T11:00:00+00:00', 'signed-9'),
      );
      expect(DateTime.parse(cursor[MultisigProposalActivityKind.created]!.timestamp), DateTime.utc(1970));
      expect(cursor[MultisigProposalActivityKind.created]!.id, '');
    });

    test('tells who did each thing, and what else the indexer recorded of it', () {
      final read = MultisigProposalActivityGraphql.sinceOf(
        {
          'm0_created': [_row('created-1', '2026-11-24T10:01:00+00:00')],
          'm0_signed': [
            _row('signed-1', '2026-11-24T10:02:00+00:00', {
              'approvals_count': 2,
              'approver': {'id': 'qzThird'},
            }),
          ],
          'm0_ready': [
            _row('ready-1', '2026-11-24T10:02:00+00:00', {
              'approvals_count': 2,
              'extrinsic': {
                'signer': {'id': 'qzThird'},
              },
            }),
          ],
          'm0_executed': [
            _row('executed-1', '2026-11-24T10:03:00+00:00', {
              'result': 'Ok',
              'extrinsic': {
                'signer': {'id': 'qzOther'},
              },
            }),
            _row('executed-2', '2026-11-24T10:04:00+00:00', {
              'result': 'Err(Module)',
              'extrinsic': {
                'signer': {'id': 'qzOther'},
              },
            }),
          ],
          'm0_cancelled': [
            _row('cancelled-1', '2026-11-24T10:05:00+00:00', {
              'cancelledBy': {'id': 'qzOther'},
            }),
          ],
          'm0_removed': [
            _row('removed-1', '2026-11-24T10:06:00+00:00', {
              'removedBy': {'id': 'qzThird'},
            }),
          ],
        },
        [_team],
        {'qzTeam': _cursor()},
      );

      final activity = read['qzTeam']!.activity;
      expect(activity.map((a) => (a.kind.name, a.id, a.actor)), [
        ('created', 'created-1', 'qzOther'),
        ('signed', 'signed-1', 'qzThird'),
        ('ready', 'ready-1', 'qzThird'),
        ('executed', 'executed-1', 'qzOther'),
        ('executed', 'executed-2', 'qzOther'),
        ('cancelled', 'cancelled-1', 'qzOther'),
        ('removed', 'removed-1', 'qzThird'),
      ]);
      expect(activity.map((a) => a.approvalsCount), [null, 2, 2, null, null, null, null]);
      expect(activity.map((a) => a.succeeded), [null, null, null, true, false, null, null]);
      for (final happened in activity) {
        expect(happened.creationHash, '0xcreated');
        expect(happened.proposal.entityId, 'qzTeam-4');
        expect(happened.proposal.amount, BigInt.from(1000));
        expect(happened.proposal.recipient, 'qzBob');
        expect((happened.proposal.threshold, happened.proposal.signerCount), (2, 3), reason: 'the wallet\'s multisig');
      }

      final cursor = read['qzTeam']!.cursor;
      expect(cursor[MultisigProposalActivityKind.executed]!.id, 'executed-2');
      expect(cursor[MultisigProposalActivityKind.executed]!.timestamp, '2026-11-24T10:04:00+00:00');
      expect(cursor[MultisigProposalActivityKind.removed]!.id, 'removed-1');
    });

    test('is in the order things happened, across kinds: at one time, in the order a proposal goes through them', () {
      final read = MultisigProposalActivityGraphql.sinceOf(
        {
          ..._nothing(1),
          'm0_ready': [
            _row('ready-1', '2026-11-24T10:02:00+00:00', {
              'approvals_count': 2,
              'extrinsic': {
                'signer': {'id': 'qzThird'},
              },
            }),
          ],
          'm0_signed': [
            _row('signed-1', '2026-11-24T10:01:00+00:00', {
              'approvals_count': 1,
              'approver': {'id': 'qzOther'},
            }),
            _row('signed-2', '2026-11-24T10:02:00.000+00:00', {
              'approvals_count': 2,
              'approver': {'id': 'qzThird'},
            }),
          ],
          'm0_created': [_row('created-1', '2026-11-24T10:01:00+00:00')],
        },
        [_team],
        {'qzTeam': _cursor()},
      );

      expect(read['qzTeam']!.activity.map((a) => a.id), ['created-1', 'signed-1', 'signed-2', 'ready-1']);
    });

    test('keeps a kind\'s cursor when nothing new of it was read', () {
      final asked = _cursor();

      final read = MultisigProposalActivityGraphql.sinceOf(_nothing(1), [_team], {'qzTeam': asked});

      expect(read['qzTeam']!.activity, isEmpty);
      for (final kind in _kinds) {
        expect(read['qzTeam']!.cursor[kind], same(asked[kind]), reason: kind.name);
      }
    });

    test('passes over a row it cannot read, and reads on after it', () {
      final read = MultisigProposalActivityGraphql.sinceOf(
        {
          ..._nothing(1),
          'm0_cancelled': [
            {'id': 'cancelled-1', 'timestamp': '2026-11-24T10:05:00+00:00', 'proposal': null},
            _row('cancelled-2', '2026-11-24T10:06:00+00:00', {
              'cancelledBy': {'id': 'qzOther'},
            }),
          ],
        },
        [_team],
        {'qzTeam': _cursor()},
      );

      expect(read['qzTeam']!.activity.map((a) => a.id), ['cancelled-2']);
      expect(read['qzTeam']!.cursor[MultisigProposalActivityKind.cancelled]!.id, 'cancelled-2');
    });

    test('keeps each multisig\'s own', () {
      final read = MultisigProposalActivityGraphql.sinceOf(
        {
          ..._nothing(2),
          'm1_created': [_row('created-1', '2026-11-24T10:01:00+00:00')],
        },
        [_team, _club],
        {'qzTeam': _cursor(), 'qzClub': _cursor()},
      );

      expect(read['qzTeam']!.activity, isEmpty);
      expect(read['qzClub']!.activity.single.proposal.multisigAddress, 'qzClub');
    });

    test('without a selection asked for is a failure', () {
      final answer = _nothing(1)..remove('m0_ready');

      expect(() => MultisigProposalActivityGraphql.sinceOf(answer, [_team], {'qzTeam': _cursor()}), throwsStateError);
    });
  });
}
