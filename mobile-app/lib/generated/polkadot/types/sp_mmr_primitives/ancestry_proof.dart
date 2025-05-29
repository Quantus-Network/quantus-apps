// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../primitive_types/h256.dart' as _i2;
import '../tuples.dart' as _i3;

class AncestryProof {
  const AncestryProof({
    required this.prevPeaks,
    required this.prevLeafCount,
    required this.leafCount,
    required this.items,
  });

  factory AncestryProof.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// Vec<Hash>
  final List<_i2.H256> prevPeaks;

  /// u64
  final BigInt prevLeafCount;

  /// NodeIndex
  final BigInt leafCount;

  /// Vec<(u64, Hash)>
  final List<_i3.Tuple2<BigInt, _i2.H256>> items;

  static const $AncestryProofCodec codec = $AncestryProofCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'prevPeaks': prevPeaks.map((value) => value.toList()).toList(),
        'prevLeafCount': prevLeafCount,
        'leafCount': leafCount,
        'items': items
            .map((value) => [
                  value.value0,
                  value.value1.toList(),
                ])
            .toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is AncestryProof &&
          _i5.listsEqual(
            other.prevPeaks,
            prevPeaks,
          ) &&
          other.prevLeafCount == prevLeafCount &&
          other.leafCount == leafCount &&
          _i5.listsEqual(
            other.items,
            items,
          );

  @override
  int get hashCode => Object.hash(
        prevPeaks,
        prevLeafCount,
        leafCount,
        items,
      );
}

class $AncestryProofCodec with _i1.Codec<AncestryProof> {
  const $AncestryProofCodec();

  @override
  void encodeTo(
    AncestryProof obj,
    _i1.Output output,
  ) {
    const _i1.SequenceCodec<_i2.H256>(_i2.H256Codec()).encodeTo(
      obj.prevPeaks,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      obj.prevLeafCount,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      obj.leafCount,
      output,
    );
    const _i1.SequenceCodec<_i3.Tuple2<BigInt, _i2.H256>>(
        _i3.Tuple2Codec<BigInt, _i2.H256>(
      _i1.U64Codec.codec,
      _i2.H256Codec(),
    )).encodeTo(
      obj.items,
      output,
    );
  }

  @override
  AncestryProof decode(_i1.Input input) {
    return AncestryProof(
      prevPeaks:
          const _i1.SequenceCodec<_i2.H256>(_i2.H256Codec()).decode(input),
      prevLeafCount: _i1.U64Codec.codec.decode(input),
      leafCount: _i1.U64Codec.codec.decode(input),
      items: const _i1.SequenceCodec<_i3.Tuple2<BigInt, _i2.H256>>(
          _i3.Tuple2Codec<BigInt, _i2.H256>(
        _i1.U64Codec.codec,
        _i2.H256Codec(),
      )).decode(input),
    );
  }

  @override
  int sizeHint(AncestryProof obj) {
    int size = 0;
    size = size +
        const _i1.SequenceCodec<_i2.H256>(_i2.H256Codec())
            .sizeHint(obj.prevPeaks);
    size = size + _i1.U64Codec.codec.sizeHint(obj.prevLeafCount);
    size = size + _i1.U64Codec.codec.sizeHint(obj.leafCount);
    size = size +
        const _i1.SequenceCodec<_i3.Tuple2<BigInt, _i2.H256>>(
            _i3.Tuple2Codec<BigInt, _i2.H256>(
          _i1.U64Codec.codec,
          _i2.H256Codec(),
        )).sizeHint(obj.items);
    return size;
  }
}
