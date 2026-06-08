import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  final service = ChainHistoryService();

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

  group('ChainHistoryService.tryParseOtherTransferEvent', () {
    test('returns null for unhandled multisig indexer account events', () {
      expect(service.tryParseOtherTransferEvent({'id': 'ae-ms-signer-approved-0000000256-qzk1'}), isNull);
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
      expect(event.networkFee, BigInt.zero);
      expect(event.deposit, multisig_pallet.Constants().multisigDeposit);
      expect(event.extrinsicHash, '0xea4400ec3247fc75b7187b6f6d83a89905017d1136c894e625a3c43a688606b9');
    });
  });

  group('MultisigCreatedEvent.fromMultisigGraphql', () {
    test('throws when threshold is missing or invalid', () {
      final base = Map<String, dynamic>.from(accountEventFixture['multisig'] as Map<String, dynamic>);

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(
          multisig: Map<String, dynamic>.from(base)..remove('threshold'),
        ),
        throwsFormatException,
      );

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(
          multisig: Map<String, dynamic>.from(base)..['threshold'] = 0,
        ),
        throwsFormatException,
      );
    });

    test('throws when signers are missing or empty', () {
      final base = Map<String, dynamic>.from(accountEventFixture['multisig'] as Map<String, dynamic>);

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(
          multisig: Map<String, dynamic>.from(base)..remove('signers'),
        ),
        throwsFormatException,
      );

      expect(
        () => MultisigCreatedEvent.fromMultisigGraphql(
          multisig: Map<String, dynamic>.from(base)..['signers'] = [],
        ),
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
      expect(withFee.totalCost, withFee.palletFee + withFee.networkFee + withFee.deposit);
    });
  });
}
