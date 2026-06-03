import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_create_submission.dart';
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

  group('MultisigAlreadyExistsException', () {
    test('toString includes address', () {
      const address = '5TestAddress';
      final error = MultisigAlreadyExistsException(address);
      expect(error.toString(), contains(address));
    });
  });

  group('MultisigService discover mapping', () {
    test('discoverForUser returns empty list for no accounts', () async {
      final result = await MultisigService().discoverForUser([]);
      expect(result, isEmpty);
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
