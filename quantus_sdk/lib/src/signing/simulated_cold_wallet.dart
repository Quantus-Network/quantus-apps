import 'package:quantus_sdk/src/models/unsigned_transaction_data.dart';
import 'package:quantus_sdk/src/rust/api/crypto.dart';
import 'package:quantus_sdk/src/rust/api/ur.dart';
import 'package:quantus_sdk/src/services/hd_wallet_service.dart';

/// A signer standing in for the cold wallet during UX testing: it answers a
/// sign request with exactly the bytes the phone would, so the hot side's
/// verification and broadcast run unchanged. Never ship a build that holds one
/// for a real account.
class SimulatedColdWallet {
  final Keypair keypair;

  const SimulatedColdWallet(this.keypair);

  /// The well-known development account (seed of zeros).
  factory SimulatedColdWallet.dev() => SimulatedColdWallet(crystalAlice());

  factory SimulatedColdWallet.fromMnemonic(
    String mnemonic, {
    int index = 0,
    DilithiumScheme scheme = DilithiumScheme.mlDsa87,
  }) => SimulatedColdWallet(HdWalletService().keyPairAtIndex(mnemonic, index, scheme));

  String get address => toAccountId(obj: keypair);

  /// The signature response as UR frames, ready to feed to a scanner.
  List<String> signRequest(UnsignedTransactionData unsigned) => encodeUr(
    data: signMessageWithPubkey(
      keypair: keypair,
      message: unsigned.encodedPayloadToSign,
      specVersion: unsigned.payloadToSign.specVersion,
    ),
  );
}
