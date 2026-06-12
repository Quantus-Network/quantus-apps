import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_create_submission.dart';
import 'package:quantus_sdk/src/models/multisig_proposal.dart';
import 'package:quantus_sdk/src/models/multisig_proposal_event.dart';
import 'package:quantus_sdk/src/models/propose_fee_breakdown.dart';
import 'package:quantus_sdk/src/services/multisig_graphql.dart';
import 'package:quantus_sdk/src/services/multisig_service.dart';

void main() {
  group('MultisigService.defaultThreshold', () {
    test('returns 1 for a single signer', () {
      expect(MultisigService.defaultThreshold(1), 1);
    });

    test('returns roughly 70% rounded for multisigs', () {
      expect(MultisigService.defaultThreshold(2), 2);
      expect(MultisigService.defaultThreshold(3), 2);
      expect(MultisigService.defaultThreshold(4), 3);
      expect(MultisigService.defaultThreshold(5), 4);
      expect(MultisigService.defaultThreshold(10), 7);
    });

    test('never exceeds signer count', () {
      expect(MultisigService.defaultThreshold(0), 1);
    });
  });

  group('MultisigService.predictMultisigAddress validation', () {
    const signerA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const signerB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

    test('throws when signers is empty', () {
      expect(MultisigService().predictMultisigAddress(signers: [], threshold: 1), throwsA(isA<ArgumentError>()));
    });

    test('throws when threshold is out of range', () {
      expect(
        MultisigService().predictMultisigAddress(signers: [signerA, signerB], threshold: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        MultisigService().predictMultisigAddress(signers: [signerA, signerB], threshold: 3),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MultisigService.buildCreateMultisigCall', () {
    const signerA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const signerB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

    test('throws when fewer than two signers', () {
      expect(
        () => MultisigService().buildCreateMultisigCall(signers: [signerA], threshold: 1, nonce: BigInt.zero),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns a Multisig runtime call for valid params', () {
      final call = MultisigService().buildCreateMultisigCall(
        signers: [signerA, signerB],
        threshold: 2,
        nonce: BigInt.zero,
      );
      expect(call.encode().isNotEmpty, isTrue);
    });
  });

  group('MultisigService.parseMultisigByPkData', () {
    test('returns null when data is null', () {
      expect(MultisigService.parseMultisigByPkData(null), isNull);
    });

    test('returns null when multisig_by_pk is null', () {
      expect(MultisigService.parseMultisigByPkData({'multisig_by_pk': null}), isNull);
    });

    test('returns record when multisig_by_pk is present', () {
      const record = {'id': '5Multisig', 'threshold': 2};
      final parsed = MultisigService.parseMultisigByPkData({'multisig_by_pk': record});
      expect(parsed, record);
    });
  });

  group('MultisigService.resolveMultisigCreationParams', () {
    const signerA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const signerB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

    Future<String> stubPredict({required List<String> signers, required int threshold, required BigInt nonce}) async {
      return 'addr_${signers.length}_${threshold}_$nonce';
    }

    test('returns lowest nonce when lower nonces are taken on-chain', () async {
      final service = MultisigService();
      final nonce0 = await stubPredict(signers: [signerA, signerB], threshold: 2, nonce: BigInt.zero);
      final nonce1 = await stubPredict(signers: [signerA, signerB], threshold: 2, nonce: BigInt.one);

      final resolved = await service.resolveMultisigCreationParams(
        signers: [signerA, signerB],
        threshold: 2,
        predictAddress: stubPredict,
        isAddressTaken: (address) async => address == nonce0 || address == nonce1,
      );

      expect(resolved.nonce, BigInt.from(2));
      expect(resolved.address, await stubPredict(signers: [signerA, signerB], threshold: 2, nonce: BigInt.from(2)));
    });

    test('does not consult isAddressTaken for reserved addresses', () async {
      final service = MultisigService();
      final reserved = await stubPredict(signers: [signerA, signerB], threshold: 2, nonce: BigInt.zero);

      final resolved = await service.resolveMultisigCreationParams(
        signers: [signerA, signerB],
        threshold: 2,
        reservedAddresses: {reserved},
        predictAddress: stubPredict,
        isAddressTaken: (address) async {
          if (address == reserved) {
            fail('should not check reserved address');
          }
          return false;
        },
      );

      expect(resolved.nonce, BigInt.one);
    });

    test('throws MultisigNonceExhaustedException when all attempts are taken', () async {
      final service = MultisigService();
      await expectLater(
        service.resolveMultisigCreationParams(
          signers: [signerA, signerB],
          threshold: 2,
          predictAddress: stubPredict,
          isAddressTaken: (_) async => true,
          maxAttempts: 3,
        ),
        throwsA(isA<MultisigNonceExhaustedException>()),
      );
    });
  });

  group('MultisigAlreadyExistsException', () {
    test('toString includes address', () {
      const address = '5TestAddress';
      final error = MultisigAlreadyExistsException(address);
      expect(error.toString(), contains(address));
    });
  });

  group('MultisigService discover mapping', () {
    const signerA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const signerB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';
    const multisigAddress = '5TestMultisig';

    const indexerRecord = {
      'id': multisigAddress,
      'threshold': 2,
      'nonce': '3',
      'signers': [signerA, signerB],
      'creator': {'id': signerA},
    };

    test('discoverForUser returns empty list for no accounts', () async {
      final result = await MultisigService().discoverForUser([]);
      expect(result, isEmpty);
    });

    test('parseMultisigDiscoverData returns empty list when data is null', () {
      expect(MultisigService.parseMultisigDiscoverData(null), isEmpty);
    });

    test('parseMultisigDiscoverData parses multisig list', () {
      final parsed = MultisigService.parseMultisigDiscoverData({
        'multisig': [indexerRecord],
      });
      expect(parsed, hasLength(1));
      expect(parsed.first['id'], multisigAddress);
    });

    test('multisigAccountFromIndexerRecord maps fields', () {
      final account = MultisigService.multisigAccountFromIndexerRecord(
        indexerRecord,
        myMemberAccountId: signerB,
        name: 'Team Multisig',
      );

      expect(account.name, 'Team Multisig');
      expect(account.accountId, multisigAddress);
      expect(account.signers, [signerA, signerB]);
      expect(account.threshold, 2);
      expect(account.nonce, BigInt.from(3));
      expect(account.myMemberAccountId, signerB);
      expect(account.creator, signerA);
    });

    test('multisigAccountFromIndexerRecord throws on malformed indexer data', () {
      expect(
        () => MultisigService.multisigAccountFromIndexerRecord(
          Map<String, dynamic>.from(indexerRecord)..remove('signers'),
          myMemberAccountId: signerB,
          name: 'Bad',
        ),
        throwsFormatException,
      );

      expect(
        () => MultisigService.multisigAccountFromIndexerRecord(
          Map<String, dynamic>.from(indexerRecord)..['signers'] = [],
          myMemberAccountId: signerB,
          name: 'Bad',
        ),
        throwsFormatException,
      );

      expect(
        () => MultisigService.multisigAccountFromIndexerRecord(
          Map<String, dynamic>.from(indexerRecord)..remove('threshold'),
          myMemberAccountId: signerB,
          name: 'Bad',
        ),
        throwsFormatException,
      );
    });

    test('multisigAccountFromIndexerRecord parses string threshold', () {
      final account = MultisigService.multisigAccountFromIndexerRecord(
        Map<String, dynamic>.from(indexerRecord)..['threshold'] = '2',
        myMemberAccountId: signerB,
        name: 'Team Multisig',
      );
      expect(account.threshold, 2);
    });

    test('resolveMyMemberAccountId prefers first matching local account', () {
      expect(MultisigService.resolveMyMemberAccountId(indexerRecord, [signerB, signerA]), signerB);
    });

    test('resolveMyMemberAccountId returns null when user is not a signer', () {
      expect(MultisigService.resolveMyMemberAccountId(indexerRecord, ['5ExternalSigner']), isNull);
    });
  });

  group('MultisigGraphql.discoverQuery', () {
    test('uses where variable', () {
      expect(MultisigGraphql.discoverQuery, contains(r'$where: multisig_bool_exp!'));
      expect(MultisigGraphql.discoverQuery, contains(r'multisig(where: $where)'));
    });
  });

  group('MultisigGraphql.buildDiscoverVariables', () {
    const addrA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const addrB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

    test('throws when accountIds is empty', () {
      expect(() => MultisigGraphql.buildDiscoverVariables([]), throwsArgumentError);
    });

    test('uses single _contains clause for one account', () {
      final variables = MultisigGraphql.buildDiscoverVariables([addrA]);
      expect(variables['where'], {
        'signers': {
          '_contains': [addrA],
        },
      });
    });

    test('uses _or of _contains clauses for multiple accounts', () {
      final variables = MultisigGraphql.buildDiscoverVariables([addrA, addrB]);
      expect(variables['where'], {
        '_or': [
          {
            'signers': {
              '_contains': [addrA],
            },
          },
          {
            'signers': {
              '_contains': [addrB],
            },
          },
        ],
      });
    });
  });

  group('MultisigProposalGraphql', () {
    const multisigAddress = '5TestMultisig';

    test('openProposalsQuery uses multisigId variable and open statuses', () {
      expect(MultisigProposalGraphql.openProposalsQuery, contains(r'$multisigId: String!'));
      expect(MultisigProposalGraphql.openProposalsQuery, contains(r'multisig_id: {_eq: $multisigId}'));
      expect(MultisigProposalGraphql.openProposalsQuery, contains('status: {_in: [ACTIVE, APPROVED]}'));
      expect(MultisigProposalGraphql.openProposalsQuery, contains('order_by: {updated_at: desc}'));
      expect(MultisigProposalGraphql.buildOpenProposalsVariables(multisigAddress), {'multisigId': multisigAddress});
    });

    test('pastProposalsQuery uses multisigId variable and terminal statuses', () {
      expect(MultisigProposalGraphql.pastProposalsQuery, contains(r'$multisigId: String!'));
      expect(MultisigProposalGraphql.pastProposalsQuery, contains(r'multisig_id: {_eq: $multisigId}'));
      expect(MultisigProposalGraphql.pastProposalsQuery, contains('status: {_in: [EXECUTED, CANCELLED, REMOVED]}'));
      expect(MultisigProposalGraphql.pastProposalsQuery, contains('order_by: {updated_at: desc}'));
      expect(MultisigProposalGraphql.buildPastProposalsVariables(multisigAddress), {'multisigId': multisigAddress});
    });

    test('proposalQuery uses multisigId and proposalId variables', () {
      expect(MultisigProposalGraphql.proposalQuery, contains(r'$multisigId: String!'));
      expect(MultisigProposalGraphql.proposalQuery, contains(r'$proposalId: Int!'));
      expect(MultisigProposalGraphql.proposalQuery, contains(r'multisig_id: {_eq: $multisigId}'));
      expect(MultisigProposalGraphql.proposalQuery, contains(r'proposal_id: {_eq: $proposalId}'));
      expect(MultisigProposalGraphql.buildProposalVariables(multisigAddress, 7), {
        'multisigId': multisigAddress,
        'proposalId': 7,
      });
    });
  });

  group('MultisigProposal.fromIndexerJson', () {
    final msig = MultisigAccount(
      name: 'Team',
      accountId: '5Multisig',
      signers: ['5Proposer', '5Other'],
      threshold: 2,
      nonce: BigInt.zero,
      myMemberAccountId: '5Proposer',
    );

    test('maps snake_case indexer fields', () {
      final proposal = MultisigProposal.fromIndexerJson({
        'id': '5Multisig-1',
        'proposal_id': 1,
        'created_at': '2026-06-04T10:00:00.000Z',
        'updated_at': '2026-06-04T10:00:00.000Z',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0500',
        'transfer_amount': '1000000000000',
        'status': 'ACTIVE',
        'expiry_block': 12345,
        'deposit': '500000000000',
        'approvals': ['5Proposer'],
        'decode_error': null,
        'proposer': {'id': '5Proposer'},
        'transferTo': {'id': '5Recipient'},
      }, msig: msig);

      expect(proposal.entityId, '5Multisig-1');
      expect(proposal.explorerProposalId, '5Multisig-1');
      expect(proposal.id, 1);
      expect(proposal.recipient, '5Recipient');
      expect(proposal.amount, BigInt.parse('1000000000000'));
      expect(proposal.status, MultisigProposalStatus.active);
      expect(proposal.approvalCount, 1);
      expect(proposal.palletFee, MultisigProposal.proposalCreationFeeFor(msig.signers.length));
    });

    test('maps unrecognized indexer status to unknown', () {
      final proposal = MultisigProposal.fromIndexerJson({
        'id': '5Multisig-9',
        'proposal_id': 9,
        'created_at': '2026-06-04T10:00:00.000Z',
        'updated_at': '2026-06-04T10:00:00.000Z',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0500',
        'transfer_amount': '1000000000000',
        'status': 'MYSTERY',
        'expiry_block': 12345,
        'deposit': '500000000000',
        'approvals': [],
        'proposer': {'id': '5Proposer'},
        'transferTo': {'id': '5Recipient'},
      }, msig: msig);

      expect(proposal.status, MultisigProposalStatus.unknown);
      expect(proposal.isOpen, isFalse);
    });

    test('reads burned_pallet_fee from indexer when present', () {
      final proposal = MultisigProposal.fromIndexerJson({
        'id': '5Multisig-3',
        'proposal_id': 3,
        'created_at': '2026-06-04T10:00:00.000Z',
        'updated_at': '2026-06-04T10:00:00.000Z',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0500',
        'transfer_amount': '1000000000000',
        'status': 'ACTIVE',
        'expiry_block': 12345,
        'deposit': '500000000000',
        'burned_pallet_fee': '1020000000000',
        'approvals': [],
        'proposer': {'id': '5Proposer'},
        'transferTo': {'id': '5Recipient'},
      }, msig: msig);

      expect(proposal.palletFee, BigInt.parse('1020000000000'));
    });

    test('maps creation network fee when present', () {
      final proposal = MultisigProposal.fromIndexerJson({
        'id': '5Multisig-2',
        'proposal_id': 2,
        'created_at': '2026-06-04T10:00:00.000Z',
        'updated_at': '2026-06-04T10:00:00.000Z',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0500',
        'transfer_amount': '1000000000000',
        'status': 'ACTIVE',
        'expiry_block': 12345,
        'deposit': '500000000000',
        'creation_network_fee': '25000000000',
        'approvals': [],
        'proposer': {'id': '5Proposer'},
        'transferTo': {'id': '5Recipient'},
      }, msig: msig);

      expect(proposal.networkFee, BigInt.parse('25000000000'));
    });

    test('maps updated_at from indexer', () {
      final proposal = MultisigProposal.fromIndexerJson({
        'id': '5Multisig-4',
        'proposal_id': 4,
        'created_at': '2026-06-04T10:00:00.000Z',
        'updated_at': '2026-06-05T14:30:00.000Z',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0500',
        'transfer_amount': '1000000000000',
        'status': 'EXECUTED',
        'expiry_block': 12345,
        'deposit': '500000000000',
        'approvals': ['5Proposer', '5Other'],
        'proposer': {'id': '5Proposer'},
        'transferTo': {'id': '5Recipient'},
      }, msig: msig);

      expect(proposal.updatedAt, DateTime.parse('2026-06-05T14:30:00.000Z'));
      expect(proposal.isTerminal, isTrue);
    });
  });

  group('MultisigProposalEvent', () {
    test('uses proposal updatedAt for activity sort timestamp', () {
      final msig = MultisigAccount(
        name: 'Team',
        accountId: '5Multisig',
        signers: ['5Proposer', '5Other'],
        threshold: 2,
        nonce: BigInt.zero,
        myMemberAccountId: '5Proposer',
      );
      final proposal = MultisigProposal.fromIndexerJson({
        'id': '5Multisig-6',
        'proposal_id': 6,
        'created_at': '2026-06-04T10:00:00.000Z',
        'updated_at': '2026-06-06T08:15:00.000Z',
        'pallet': 'Balances',
        'call': 'transfer_allow_death',
        'call_raw': '0x0500',
        'transfer_amount': '1000000000000',
        'status': 'EXECUTED',
        'expiry_block': 12345,
        'deposit': '500000000000',
        'approvals': ['5Proposer', '5Other'],
        'proposer': {'id': '5Proposer'},
        'transferTo': {'id': '5Recipient'},
      }, msig: msig);

      final event = MultisigProposalEvent(proposal: proposal);

      expect(event.timestamp, proposal.updatedAt);
      expect(event.timestamp, isNot(proposal.createdAt));
    });
  });

  group('MultisigService.buildApproveCall', () {
    test('returns a Multisig runtime call for valid params', () {
      final call = MultisigService().buildApproveCall(msig: _buildTestMsig(), proposalId: 3);
      expect(call.encode().isNotEmpty, isTrue);
    });
  });

  group('MultisigService.buildExecuteCall', () {
    test('returns a Multisig runtime call for valid params', () {
      final call = MultisigService().buildExecuteCall(msig: _buildTestMsig(), proposalId: 3);
      expect(call.encode().isNotEmpty, isTrue);
    });
  });

  group('MultisigService.buildCancelCall', () {
    const signerA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const signerB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';
    const multisigAddress = '5DAAnrj7VHTznn2AWBemMuyBwZWs6FNFjdyVXUeYum3PTXFy';

    final msig = MultisigAccount(
      name: 'Team',
      accountId: multisigAddress,
      signers: [signerA, signerB],
      threshold: 2,
      nonce: BigInt.zero,
      myMemberAccountId: signerA,
    );

    test('returns a Multisig runtime call for valid params', () {
      final call = MultisigService().buildCancelCall(msig: msig, proposalId: 3);
      expect(call.encode().isNotEmpty, isTrue);
    });
  });

  group('MultisigService.proposalCreationFee', () {
    final service = MultisigService();
    final base = service.proposalFee;
    final signerStepFactor = BigInt.from(MultisigService.palletConstants.signerStepFactor);

    test('scales with signer count per pallet formula', () {
      BigInt expected(int signerCount) {
        final extra = base * BigInt.from(signerCount) * signerStepFactor ~/ BigInt.from(1000000);
        return base + extra;
      }

      expect(service.proposalCreationFee(1), expected(1));
      expect(service.proposalCreationFee(5), expected(5));
      expect(service.proposalCreationFee(10), expected(10));
    });

    test('matches pallet example: 5 signers adds 5% to base', () {
      final extra = base * BigInt.from(5) * signerStepFactor ~/ BigInt.from(1000000);
      expect(extra, base ~/ BigInt.from(20));
      expect(service.proposalCreationFee(5), base + extra);
    });
  });

  group('ProposeFeeBreakdown', () {
    test('memberCost sums network, deposit, and creation fees', () {
      final breakdown = ProposeFeeBreakdown(
        networkFee: BigInt.from(100),
        deposit: BigInt.from(200),
        creationFee: BigInt.from(300),
        expiryBlock: 14400,
      );
      expect(breakdown.memberCost, BigInt.from(600));
    });
  });

  group('MultisigAccount', () {
    test('fromJson round-trip preserves fields', () {
      final account = MultisigAccount(
        name: 'Multisig',
        accountId: '5TestMultisig',
        signers: ['5SignerA', '5SignerB'],
        threshold: 2,
        nonce: BigInt.from(3),
        myMemberAccountId: '5SignerA',
        creator: '5SignerA',
      );
      final restored = MultisigAccount.fromJson(account.toJson());
      expect(restored.accountId, account.accountId);
      expect(restored.signers, account.signers);
      expect(restored.threshold, account.threshold);
      expect(restored.nonce, account.nonce);
      expect(restored.myMemberAccountId, account.myMemberAccountId);
      expect(restored.creator, account.creator);
    });
  });
}

/// Two-signer multisig fixture shared by the call-building test groups.
MultisigAccount _buildTestMsig() {
  const signerA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
  const signerB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';
  const multisigAddress = '5DAAnrj7VHTznn2AWBemMuyBwZWs6FNFjdyVXUeYum3PTXFy';

  return MultisigAccount(
    name: 'Team',
    accountId: multisigAddress,
    signers: [signerA, signerB],
    threshold: 2,
    nonce: BigInt.zero,
    myMemberAccountId: signerB,
  );
}
