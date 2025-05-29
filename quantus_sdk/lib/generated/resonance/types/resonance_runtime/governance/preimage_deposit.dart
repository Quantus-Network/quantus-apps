// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

class PreimageDeposit {
  const PreimageDeposit({required this.amount});

  factory PreimageDeposit.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// Balance
  final BigInt amount;

  static const $PreimageDepositCodec codec = $PreimageDepositCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, BigInt> toJson() => {'amount': amount};

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PreimageDeposit && other.amount == amount;

  @override
  int get hashCode => amount.hashCode;
}

class $PreimageDepositCodec with _i1.Codec<PreimageDeposit> {
  const $PreimageDepositCodec();

  @override
  void encodeTo(
    PreimageDeposit obj,
    _i1.Output output,
  ) {
    _i1.U128Codec.codec.encodeTo(
      obj.amount,
      output,
    );
  }

  @override
  PreimageDeposit decode(_i1.Input input) {
    return PreimageDeposit(amount: _i1.U128Codec.codec.decode(input));
  }

  @override
  int sizeHint(PreimageDeposit obj) {
    int size = 0;
    size = size + _i1.U128Codec.codec.sizeHint(obj.amount);
    return size;
  }
}
