// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

enum ProposalStatus {
  active('Active', 0),
  approved('Approved', 1);

  const ProposalStatus(this.variantName, this.codecIndex);

  factory ProposalStatus.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $ProposalStatusCodec codec = $ProposalStatusCodec();

  String toJson() => variantName;

  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $ProposalStatusCodec with _i1.Codec<ProposalStatus> {
  const $ProposalStatusCodec();

  @override
  ProposalStatus decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return ProposalStatus.active;
      case 1:
        return ProposalStatus.approved;
      default:
        throw Exception('ProposalStatus: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(ProposalStatus value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
