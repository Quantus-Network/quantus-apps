import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/shared/utils/multisig_signer_check.dart';

void main() {
  const known = 'qzknown';
  const other = 'qzother';

  test('a multisig known on this device answers without a chain lookup', () async {
    var lookups = 0;
    final result = await isMultisigSigner(
      known,
      knownMultisigs: {known},
      isOnChainMultisig: (_) async {
        lookups++;
        return false;
      },
    );

    expect(result, isTrue);
    expect(lookups, 0);
  });

  test('anything else is decided by the chain lookup', () async {
    expect(await isMultisigSigner(other, knownMultisigs: {known}, isOnChainMultisig: (_) async => true), isTrue);
    expect(await isMultisigSigner(other, knownMultisigs: {known}, isOnChainMultisig: (_) async => false), isFalse);
  });

  test('a failed lookup propagates instead of reading as not a multisig', () {
    expect(
      isMultisigSigner(other, knownMultisigs: const {}, isOnChainMultisig: (_) async => throw Exception('rpc down')),
      throwsException,
    );
  });
}
