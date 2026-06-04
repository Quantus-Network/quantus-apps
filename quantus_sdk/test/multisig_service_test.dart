import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/src/models/multisig_account.dart';
import 'package:quantus_sdk/src/models/multisig_create_submission.dart';
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

    test('resolveMyMemberAccountId prefers first matching local account', () {
      expect(MultisigService.resolveMyMemberAccountId(indexerRecord, [signerB, signerA]), signerB);
    });

    test('resolveMyMemberAccountId returns null when user is not a signer', () {
      expect(MultisigService.resolveMyMemberAccountId(indexerRecord, ['5ExternalSigner']), isNull);
    });
  });

  group('MultisigGraphql.buildDiscoverQuery', () {
    const addrA = '5GrwvaEF5zXb26Fz9rcQpDWS57CtERHpNehXCPcNoHGKutQY';
    const addrB = '5FHneW46xGXgs5mUiveU4sbTyGBzmstUspZC92UhjJM694ty';

    test('throws when accountIds is empty', () {
      expect(() => MultisigGraphql.buildDiscoverQuery([]), throwsArgumentError);
    });

    test('uses single _contains clause for one account', () {
      final query = MultisigGraphql.buildDiscoverQuery([addrA]);
      expect(query, contains('{signers: {_contains: ["$addrA"]}}'));
      expect(query, isNot(contains('_or')));
    });

    test('uses _or of _contains clauses for multiple accounts', () {
      final query = MultisigGraphql.buildDiscoverQuery([addrA, addrB]);
      expect(query, contains('_or'));
      expect(query, contains('{signers: {_contains: ["$addrA"]}}'));
      expect(query, contains('{signers: {_contains: ["$addrB"]}}'));
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
