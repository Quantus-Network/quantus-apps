// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

class Tally {
  const Tally({
    required this.bareAyes,
    required this.ayes,
    required this.nays,
  });

  factory Tally.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// MemberIndex
  final int bareAyes;

  /// Votes
  final int ayes;

  /// Votes
  final int nays;

  static const $TallyCodec codec = $TallyCodec();

  _i2.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, int> toJson() => {
        'bareAyes': bareAyes,
        'ayes': ayes,
        'nays': nays,
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is Tally &&
          other.bareAyes == bareAyes &&
          other.ayes == ayes &&
          other.nays == nays;

  @override
  int get hashCode => Object.hash(
        bareAyes,
        ayes,
        nays,
      );
}

class $TallyCodec with _i1.Codec<Tally> {
  const $TallyCodec();

  @override
  void encodeTo(
    Tally obj,
    _i1.Output output,
  ) {
    _i1.U32Codec.codec.encodeTo(
      obj.bareAyes,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      obj.ayes,
      output,
    );
    _i1.U32Codec.codec.encodeTo(
      obj.nays,
      output,
    );
  }

  @override
  Tally decode(_i1.Input input) {
    return Tally(
      bareAyes: _i1.U32Codec.codec.decode(input),
      ayes: _i1.U32Codec.codec.decode(input),
      nays: _i1.U32Codec.codec.decode(input),
    );
  }

  @override
  int sizeHint(Tally obj) {
    int size = 0;
    size = size + _i1.U32Codec.codec.sizeHint(obj.bareAyes);
    size = size + _i1.U32Codec.codec.sizeHint(obj.ayes);
    size = size + _i1.U32Codec.codec.sizeHint(obj.nays);
    return size;
  }
}
