// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// The specified airdrop does not exist.
  airdropNotFound('AirdropNotFound', 0),

  /// The airdrop does not have sufficient balance for this operation.
  insufficientAirdropBalance('InsufficientAirdropBalance', 1),

  /// The user has already claimed from this airdrop.
  alreadyClaimed('AlreadyClaimed', 2),

  /// The provided Merkle proof is invalid.
  invalidProof('InvalidProof', 3),

  /// Only the creator of an airdrop can delete it.
  notAirdropCreator('NotAirdropCreator', 4);

  const Error(
    this.variantName,
    this.codecIndex,
  );

  factory Error.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $ErrorCodec codec = $ErrorCodec();

  String toJson() => variantName;
  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $ErrorCodec with _i1.Codec<Error> {
  const $ErrorCodec();

  @override
  Error decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Error.airdropNotFound;
      case 1:
        return Error.insufficientAirdropBalance;
      case 2:
        return Error.alreadyClaimed;
      case 3:
        return Error.invalidProof;
      case 4:
        return Error.notAirdropCreator;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Error value,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      value.codecIndex,
      output,
    );
  }
}
