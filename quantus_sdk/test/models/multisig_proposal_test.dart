import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/planck/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';

final bobId = Uint8List.fromList(List.filled(32, 0xBB));

MultisigProposal proposalWith({Uint8List? callRaw}) => MultisigProposal(
  entityId: 'p1',
  id: 1,
  multisigAddress: 'msig',
  proposer: 'proposer',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  pallet: '',
  call: '',
  recipient: '',
  amount: BigInt.zero,
  callRaw: callRaw,
  expiryBlock: 100,
  approvals: const [],
  deposit: BigInt.zero,
  status: MultisigProposalStatus.active,
  threshold: 2,
  signerCount: 3,
);

void main() {
  final transferBytes = Uint8List.fromList(
    const balances_pallet.Txs()
        .transferAllowDeath(dest: multi_address.MultiAddress.values.id(bobId), value: BigInt.from(1000000000000))
        .encode(),
  );

  group('hasUndecodableCall', () {
    test('false when the indexer supplied no call bytes', () {
      final proposal = proposalWith();
      expect(proposal.hasUndecodableCall, isFalse);
      expect(proposal.decodedCall, isNull);
    });

    test('false for a decodable transfer call', () {
      final proposal = proposalWith(callRaw: transferBytes);
      expect(proposal.hasUndecodableCall, isFalse);
      expect(proposal.decodedCall?.call, 'transfer_allow_death');
    });

    test('true when a valid call is followed by trailing bytes', () {
      final proposal = proposalWith(callRaw: Uint8List.fromList([...transferBytes, 0x00]));
      expect(proposal.hasUndecodableCall, isTrue);
      expect(proposal.decodedCall, isNull);
    });

    test('true for an unknown pallet index', () {
      final proposal = proposalWith(callRaw: Uint8List.fromList([250, 0]));
      expect(proposal.hasUndecodableCall, isTrue);
    });
  });
}
