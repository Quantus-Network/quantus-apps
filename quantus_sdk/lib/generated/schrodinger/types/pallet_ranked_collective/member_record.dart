// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

class MemberRecord {
  const MemberRecord({required this.rank});

  factory MemberRecord.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// Rank
  final int rank;

  static const $MemberRecordCodec codec = $MemberRecordCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, int> toJson() => {'rank': rank};

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MemberRecord && other.rank == rank;

  @override
  int get hashCode => rank.hashCode;
}

class $MemberRecordCodec with _i1.Codec<MemberRecord> {
  const $MemberRecordCodec();

  @override
  void encodeTo(
    MemberRecord obj,
    _i1.Output output,
  ) {
    _i1.U16Codec.codec.encodeTo(
      obj.rank,
      output,
    );
  }

  @override
  MemberRecord decode(_i1.Input input) {
    return MemberRecord(rank: _i1.U16Codec.codec.decode(input));
  }

  @override
  int sizeHint(MemberRecord obj) {
    int size = 0;
    size = size + _i1.U16Codec.codec.sizeHint(obj.rank);
    return size;
  }
}
