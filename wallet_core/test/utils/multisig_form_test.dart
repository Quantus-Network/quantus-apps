import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/utils/multisig_form.dart';

const _payer = 'qzPayer';
const _other = 'qzOther';
const _new = 'qzNew';
const _saved = 'qzSaved';
const _creating = 'qzCreating';
const _invalid = 'not-an-address';

MultisigAccount _multisig(String accountId) => MultisigAccount(
  name: 'Team',
  accountId: accountId,
  signers: const [_payer, _other],
  threshold: 1,
  nonce: BigInt.zero,
  myMemberAccountId: _payer,
);

void main() {
  group('newSignerProblem', () {
    SignerProblem? problemOf(String address, {Set<String> reserved = const {_saved, _creating}}) => newSignerProblem(
      address,
      isValidAddress: (a) => !a.startsWith('not-'),
      signers: const [_payer, _other],
      reserved: reserved,
    );

    test('a valid new address has no problem', () {
      expect(problemOf(_new), isNull);
    });

    test('an invalid address is reported', () {
      expect(problemOf(_invalid), SignerProblem.invalid);
    });

    test('the payer and a listed signer are duplicates', () {
      expect(problemOf(_payer), SignerProblem.duplicate);
      expect(problemOf(_other), SignerProblem.duplicate);
    });

    test('a saved multisig and one being created are reported as multisigs', () {
      expect(problemOf(_saved), SignerProblem.isMultisig);
      expect(problemOf(_creating), SignerProblem.isMultisig);
    });

    test('invalid is reported before duplicate and multisig', () {
      final problem = newSignerProblem(
        _invalid,
        isValidAddress: (_) => false,
        signers: const [_invalid],
        reserved: const {_invalid},
      );

      expect(problem, SignerProblem.invalid);
    });

    test('duplicate is reported before multisig', () {
      expect(problemOf(_other, reserved: const {_other}), SignerProblem.duplicate);
    });
  });

  group('reservedMultisigAddresses', () {
    test('holds the saved multisigs and those being created', () {
      final creating = _multisig(_creating);

      expect(
        reservedMultisigAddresses(
          saved: [_multisig(_saved)],
          creating: [PendingMultisigCreationEvent.fromDraft(creating, networkFee: BigInt.one)],
        ),
        {_saved, _creating},
      );
    });

    test('is empty when there are neither', () {
      expect(reservedMultisigAddresses(saved: const [], creating: const []), isEmpty);
    });
  });

  group('multisigSigners', () {
    test('puts the payer first', () {
      expect(multisigSigners(_payer, const [_other, _new]), [_payer, _other, _new]);
    });

    test('without a payer is only the others', () {
      expect(multisigSigners(null, const [_other]), [_other]);
    });
  });

  group('canCreateMultisig', () {
    bool canCreate({
      String name = 'Team',
      List<String> signers = const [_payer, _other],
      bool hasPayer = true,
      bool hasNonce = true,
      bool isPreviewing = false,
      bool isSubmitting = false,
    }) => canCreateMultisig(
      name: name,
      signers: signers,
      hasPayer: hasPayer,
      nonce: hasNonce ? BigInt.zero : null,
      isPreviewing: isPreviewing,
      isSubmitting: isSubmitting,
    );

    test('is true with everything in place', () {
      expect(canCreate(), isTrue);
    });

    test('needs a name that is not blank', () {
      expect(canCreate(name: ''), isFalse);
      expect(canCreate(name: '   '), isFalse);
    });

    test('needs at least two signers', () {
      expect(canCreate(signers: const [_payer]), isFalse);
    });

    test('needs a payer', () {
      expect(canCreate(hasPayer: false), isFalse);
    });

    test('needs a resolved nonce', () {
      expect(canCreate(hasNonce: false), isFalse);
    });

    test('waits for a running preview', () {
      expect(canCreate(isPreviewing: true), isFalse);
    });

    test('is false while submitting', () {
      expect(canCreate(isSubmitting: true), isFalse);
    });
  });
}
