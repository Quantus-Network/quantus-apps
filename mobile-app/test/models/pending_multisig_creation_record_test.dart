import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/pending_multisig_creation_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingMultisigCreationRecord', () {
    final draft = MultisigAccount(
      name: 'Team Wallet',
      accountId: '5GrwvaEF5zXb26Fz9rcQpDWS57CtEGASjEi3Uf1Y7K',
      signers: const ['5GrwvaEF5zXb26Fz9rcQpDWS57CtEGASjEi3Uf1Y7K', '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty'],
      threshold: 2,
      nonce: BigInt.zero,
      myMemberAccountId: '5GrwvaEF5zXb26Fz9rcQpDWS57CtEGASjEi3Uf1Y7K',
      creator: '5GrwvaEF5zXb26Fz9rcQpDWS57CtEGASjEi3Uf1Y7K',
    );

    test('round-trips through JSON', () {
      final submittedAt = DateTime(2026, 6, 8, 12, 30);
      final networkFee = BigInt.from(123456789);
      const extrinsicHash = '0xabc123';

      final record = PendingMultisigCreationRecord(
        draft: draft,
        networkFee: networkFee,
        submittedAt: submittedAt,
        extrinsicHash: extrinsicHash,
      );

      final restored = PendingMultisigCreationRecord.fromJson(record.toJson());

      expect(restored.draft.name, draft.name);
      expect(restored.draft.accountId, draft.accountId);
      expect(restored.draft.signers, draft.signers);
      expect(restored.draft.threshold, draft.threshold);
      expect(restored.draft.nonce, draft.nonce);
      expect(restored.networkFee, networkFee);
      expect(restored.submittedAt, submittedAt);
      expect(restored.extrinsicHash, extrinsicHash);
    });

    test('toEvent preserves draft fields and fees', () {
      final submittedAt = DateTime(2026, 6, 8, 12, 30);
      final networkFee = BigInt.from(987654321);

      final event = PendingMultisigCreationRecord(
        draft: draft,
        networkFee: networkFee,
        submittedAt: submittedAt,
      ).toEvent();

      expect(event.multisigAddress, draft.accountId);
      expect(event.creatorId, draft.creator);
      expect(event.threshold, draft.threshold);
      expect(event.nonce, draft.nonce);
      expect(event.signers, draft.signers);
      expect(event.networkFee, networkFee);
      expect(event.timestamp, submittedAt);
      expect(event.id, 'pending_multisig_${draft.accountId}');
    });

    test('isExpired respects the polling window', () {
      final recent = PendingMultisigCreationRecord(
        draft: draft,
        networkFee: BigInt.zero,
        submittedAt: DateTime.now().subtract(const Duration(minutes: 4)),
      );
      final stale = PendingMultisigCreationRecord(
        draft: draft,
        networkFee: BigInt.zero,
        submittedAt: DateTime.now().subtract(const Duration(minutes: 6)),
      );

      expect(recent.isExpired(expiration: const Duration(minutes: 5)), isFalse);
      expect(stale.isExpired(expiration: const Duration(minutes: 5)), isTrue);
    });
  });
}
