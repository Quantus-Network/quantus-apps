// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../primitive_types/h256.dart' as _i3;
import 'candidate_descriptor_v2.dart' as _i2;

class CandidateReceiptV2 {
  const CandidateReceiptV2({
    required this.descriptor,
    required this.commitmentsHash,
  });

  factory CandidateReceiptV2.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// CandidateDescriptorV2<H>
  final _i2.CandidateDescriptorV2 descriptor;

  /// Hash
  final _i3.H256 commitmentsHash;

  static const $CandidateReceiptV2Codec codec = $CandidateReceiptV2Codec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'descriptor': descriptor.toJson(),
        'commitmentsHash': commitmentsHash.toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CandidateReceiptV2 &&
          other.descriptor == descriptor &&
          _i5.listsEqual(
            other.commitmentsHash,
            commitmentsHash,
          );

  @override
  int get hashCode => Object.hash(
        descriptor,
        commitmentsHash,
      );
}

class $CandidateReceiptV2Codec with _i1.Codec<CandidateReceiptV2> {
  const $CandidateReceiptV2Codec();

  @override
  void encodeTo(
    CandidateReceiptV2 obj,
    _i1.Output output,
  ) {
    _i2.CandidateDescriptorV2.codec.encodeTo(
      obj.descriptor,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.commitmentsHash,
      output,
    );
  }

  @override
  CandidateReceiptV2 decode(_i1.Input input) {
    return CandidateReceiptV2(
      descriptor: _i2.CandidateDescriptorV2.codec.decode(input),
      commitmentsHash: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  @override
  int sizeHint(CandidateReceiptV2 obj) {
    int size = 0;
    size = size + _i2.CandidateDescriptorV2.codec.sizeHint(obj.descriptor);
    size = size + const _i3.H256Codec().sizeHint(obj.commitmentsHash);
    return size;
  }
}
