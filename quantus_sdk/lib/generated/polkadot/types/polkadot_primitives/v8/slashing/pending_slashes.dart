// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../../b_tree_map_7.dart' as _i2;
import '../../../tuples.dart' as _i6;
import '../validator_app/public.dart' as _i8;
import '../validator_index.dart' as _i7;
import 'slashing_offence_kind.dart' as _i3;

class PendingSlashes {
  const PendingSlashes({
    required this.keys,
    required this.kind,
  });

  factory PendingSlashes.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// BTreeMap<ValidatorIndex, ValidatorId>
  final _i2.BTreeMap keys;

  /// SlashingOffenceKind
  final _i3.SlashingOffenceKind kind;

  static const $PendingSlashesCodec codec = $PendingSlashesCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'keys': keys
            .map((value) => [
                  value.value0,
                  value.value1.toList(),
                ])
            .toList(),
        'kind': kind.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is PendingSlashes &&
          _i5.listsEqual(
            other.keys,
            keys,
          ) &&
          other.kind == kind;

  @override
  int get hashCode => Object.hash(
        keys,
        kind,
      );
}

class $PendingSlashesCodec with _i1.Codec<PendingSlashes> {
  const $PendingSlashesCodec();

  @override
  void encodeTo(
    PendingSlashes obj,
    _i1.Output output,
  ) {
    const _i1.SequenceCodec<_i6.Tuple2<_i7.ValidatorIndex, _i8.Public>>(
        _i6.Tuple2Codec<_i7.ValidatorIndex, _i8.Public>(
      _i7.ValidatorIndexCodec(),
      _i8.PublicCodec(),
    )).encodeTo(
      obj.keys,
      output,
    );
    _i3.SlashingOffenceKind.codec.encodeTo(
      obj.kind,
      output,
    );
  }

  @override
  PendingSlashes decode(_i1.Input input) {
    return PendingSlashes(
      keys: const _i1.SequenceCodec<_i6.Tuple2<_i7.ValidatorIndex, _i8.Public>>(
          _i6.Tuple2Codec<_i7.ValidatorIndex, _i8.Public>(
        _i7.ValidatorIndexCodec(),
        _i8.PublicCodec(),
      )).decode(input),
      kind: _i3.SlashingOffenceKind.codec.decode(input),
    );
  }

  @override
  int sizeHint(PendingSlashes obj) {
    int size = 0;
    size = size + const _i2.BTreeMapCodec().sizeHint(obj.keys);
    size = size + _i3.SlashingOffenceKind.codec.sizeHint(obj.kind);
    return size;
  }
}
