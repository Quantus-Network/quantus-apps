// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../v8/candidate_commitments.dart' as _i3;
import 'candidate_descriptor_v2.dart' as _i2;

class CommittedCandidateReceiptV2 {
  const CommittedCandidateReceiptV2({
    required this.descriptor,
    required this.commitments,
  });

  factory CommittedCandidateReceiptV2.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// CandidateDescriptorV2<H>
  final _i2.CandidateDescriptorV2 descriptor;

  /// CandidateCommitments
  final _i3.CandidateCommitments commitments;

  static const $CommittedCandidateReceiptV2Codec codec =
      $CommittedCandidateReceiptV2Codec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, Map<String, dynamic>> toJson() => {
        'descriptor': descriptor.toJson(),
        'commitments': commitments.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is CommittedCandidateReceiptV2 &&
          other.descriptor == descriptor &&
          other.commitments == commitments;

  @override
  int get hashCode => Object.hash(
        descriptor,
        commitments,
      );
}

class $CommittedCandidateReceiptV2Codec
    with _i1.Codec<CommittedCandidateReceiptV2> {
  const $CommittedCandidateReceiptV2Codec();

  @override
  void encodeTo(
    CommittedCandidateReceiptV2 obj,
    _i1.Output output,
  ) {
    _i2.CandidateDescriptorV2.codec.encodeTo(
      obj.descriptor,
      output,
    );
    _i3.CandidateCommitments.codec.encodeTo(
      obj.commitments,
      output,
    );
  }

  @override
  CommittedCandidateReceiptV2 decode(_i1.Input input) {
    return CommittedCandidateReceiptV2(
      descriptor: _i2.CandidateDescriptorV2.codec.decode(input),
      commitments: _i3.CandidateCommitments.codec.decode(input),
    );
  }

  @override
  int sizeHint(CommittedCandidateReceiptV2 obj) {
    int size = 0;
    size = size + _i2.CandidateDescriptorV2.codec.sizeHint(obj.descriptor);
    size = size + _i3.CandidateCommitments.codec.sizeHint(obj.commitments);
    return size;
  }
}
