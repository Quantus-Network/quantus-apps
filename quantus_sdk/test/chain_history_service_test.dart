import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/multisig.dart' as multisig_pallet;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/services/chain_history_service.dart';

void main() {
  final service = ChainHistoryService();

  const accountEventFixture = {
    'id': 'ae-multisig-qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH-qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7',
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
      'block': {
        'height': 3,
        'hash': '0xdfee413c921789a93b641c2eaf25be8c3d7770841cc7e83aff369cdd882eb9f4',
      },
      'extrinsic': {'id': '0xea4400ec3247fc75b7187b6f6d83a89905017d1136c894e625a3c43a688606b9'},
    },
  };

  group('ChainHistoryService.tryParseOtherTransferEvent', () {
    test('returns null for other multisig indexer account events', () {
      expect(
        service.tryParseOtherTransferEvent({
          'id': 'ae-ms-proposal-created-0000000256-c9dc5-000005-qzk1',
        }),
        isNull,
      );
    });

    test('parses multisig account events', () {
      final result = service.tryParseOtherTransferEvent(accountEventFixture);
      expect(result, isA<MultisigCreatedEvent>());

      final event = result! as MultisigCreatedEvent;
      expect(event.creatorId, 'qzk1Nxai3dZD9Cn5kwGcgL6mKxsfxwqdis7kDQJ52aJS2vSn7');
      expect(event.multisigAddress, 'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH');
      expect(event.threshold, 2);
      expect(event.signers, hasLength(3));
      expect(event.creationFee, multisig_pallet.Constants().multisigFee);
      expect(event.deposit, multisig_pallet.Constants().multisigDeposit);
      expect(
        event.extrinsicHash,
        '0xea4400ec3247fc75b7187b6f6d83a89905017d1136c894e625a3c43a688606b9',
      );
    });
  });

  group('MultisigCreatedEvent.fromMultisigGraphql', () {
    test('defaults threshold to 1 when missing or invalid', () {
      final base = Map<String, dynamic>.from(
        accountEventFixture['multisig'] as Map<String, dynamic>,
      );

      final missing = MultisigCreatedEvent.fromMultisigGraphql(
        multisig: Map<String, dynamic>.from(base)..remove('threshold'),
      );
      expect(missing.threshold, 1);

      final zero = MultisigCreatedEvent.fromMultisigGraphql(
        multisig: Map<String, dynamic>.from(base)..['threshold'] = 0,
      );
      expect(zero.threshold, 1);
    });
  });

  group('ChainHistoryService.mergeMultisigCreations', () {
    test('dedupes supplemental when account_event already parsed', () {
      final fromEvent = service.tryParseOtherTransferEvent(accountEventFixture)!;

      final supplemental = MultisigCreatedEvent.fromMultisigGraphql(
        multisig: accountEventFixture['multisig'] as Map<String, dynamic>,
      );

      final merged = ChainHistoryService.mergeMultisigCreations(
        events: [fromEvent],
        supplemental: [supplemental],
      );

      expect(merged, hasLength(1));
      expect(merged.single, isA<MultisigCreatedEvent>());
    });

    test('adds supplemental when missing from account events', () {
      final supplemental = MultisigCreatedEvent.fromMultisigGraphql(
        multisig: accountEventFixture['multisig'] as Map<String, dynamic>,
      );

      final merged = ChainHistoryService.mergeMultisigCreations(
        events: [],
        supplemental: [supplemental],
      );

      expect(merged, hasLength(1));
      expect((merged.single as MultisigCreatedEvent).multisigAddress,
          'qzo4qS1Lw6J66JuXcxLEWgzBLX2sBe3Ak3kmN1oA17pXLKCFH');
    });
  });
}
