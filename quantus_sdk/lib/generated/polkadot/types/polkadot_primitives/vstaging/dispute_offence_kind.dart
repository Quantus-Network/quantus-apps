// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

enum DisputeOffenceKind {
  forInvalidBacked('ForInvalidBacked', 0),
  againstValid('AgainstValid', 1),
  forInvalidApproved('ForInvalidApproved', 2);

  const DisputeOffenceKind(
    this.variantName,
    this.codecIndex,
  );

  factory DisputeOffenceKind.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $DisputeOffenceKindCodec codec = $DisputeOffenceKindCodec();

  String toJson() => variantName;
  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $DisputeOffenceKindCodec with _i1.Codec<DisputeOffenceKind> {
  const $DisputeOffenceKindCodec();

  @override
  DisputeOffenceKind decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return DisputeOffenceKind.forInvalidBacked;
      case 1:
        return DisputeOffenceKind.againstValid;
      case 2:
        return DisputeOffenceKind.forInvalidApproved;
      default:
        throw Exception('DisputeOffenceKind: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    DisputeOffenceKind value,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      value.codecIndex,
      output,
    );
  }
}
