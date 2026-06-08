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

  group('ChainHistoryService.tryParseOtherTransferEvent', () {
    test('returns null for other multisig indexer account events', () {
      expect(service.tryParseOtherTransferEvent({'id': 'ae-ms-proposal-created-0000000256-c9dc5-000005-qzk1'}), isNull);
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
