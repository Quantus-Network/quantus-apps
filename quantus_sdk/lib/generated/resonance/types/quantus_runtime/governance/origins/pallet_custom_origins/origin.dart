// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

enum Origin {
  treasurer('Treasurer', 0),
  smallSpender('SmallSpender', 1),
  mediumSpender('MediumSpender', 2),
  bigSpender('BigSpender', 3);

  const Origin(
    this.variantName,
    this.codecIndex,
  );

  factory Origin.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $OriginCodec codec = $OriginCodec();

  String toJson() => variantName;
  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $OriginCodec with _i1.Codec<Origin> {
  const $OriginCodec();

  @override
  Origin decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Origin.treasurer;
      case 1:
        return Origin.smallSpender;
      case 2:
        return Origin.mediumSpender;
      case 3:
        return Origin.bigSpender;
      default:
        throw Exception('Origin: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Origin value,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      value.codecIndex,
      output,
    );
  }
}
