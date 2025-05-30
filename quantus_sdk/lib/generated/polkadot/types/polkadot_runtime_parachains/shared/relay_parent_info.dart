// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../../b_tree_map_4.dart' as _i3;
import '../../b_tree_map_5.dart' as _i8;
import '../../polkadot_parachain_primitives/primitives/id.dart' as _i7;
import '../../primitive_types/h256.dart' as _i2;
import '../../tuples.dart' as _i6;

class RelayParentInfo {
  const RelayParentInfo({
    required this.relayParent,
    required this.stateRoot,
    required this.claimQueue,
  });

  factory RelayParentInfo.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// Hash
  final _i2.H256 relayParent;

  /// Hash
  final _i2.H256 stateRoot;

  /// BTreeMap<Id, BTreeMap<u8, BTreeSet<CoreIndex>>>
  final _i3.BTreeMap claimQueue;

  static const $RelayParentInfoCodec codec = $RelayParentInfoCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, List<dynamic>> toJson() => {
        'relayParent': relayParent.toList(),
        'stateRoot': stateRoot.toList(),
        'claimQueue': claimQueue
            .map((value) => [
                  value.value0,
                  value.value1
                      .map((value) => [
                            value.value0,
                            value.value1.map((value) => value).toList(),
                          ])
                      .toList(),
                ])
            .toList(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RelayParentInfo &&
          _i5.listsEqual(
            other.relayParent,
            relayParent,
          ) &&
          _i5.listsEqual(
            other.stateRoot,
            stateRoot,
          ) &&
          _i5.listsEqual(
            other.claimQueue,
            claimQueue,
          );

  @override
  int get hashCode => Object.hash(
        relayParent,
        stateRoot,
        claimQueue,
      );
}

class $RelayParentInfoCodec with _i1.Codec<RelayParentInfo> {
  const $RelayParentInfoCodec();

  @override
  void encodeTo(
    RelayParentInfo obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.relayParent,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.stateRoot,
      output,
    );
    const _i1.SequenceCodec<_i6.Tuple2<_i7.Id, _i8.BTreeMap>>(
        _i6.Tuple2Codec<_i7.Id, _i8.BTreeMap>(
      _i7.IdCodec(),
      _i8.BTreeMapCodec(),
    )).encodeTo(
      obj.claimQueue,
      output,
    );
  }

  @override
  RelayParentInfo decode(_i1.Input input) {
    return RelayParentInfo(
      relayParent: const _i1.U8ArrayCodec(32).decode(input),
      stateRoot: const _i1.U8ArrayCodec(32).decode(input),
      claimQueue: const _i1.SequenceCodec<_i6.Tuple2<_i7.Id, _i8.BTreeMap>>(
          _i6.Tuple2Codec<_i7.Id, _i8.BTreeMap>(
        _i7.IdCodec(),
        _i8.BTreeMapCodec(),
      )).decode(input),
    );
  }

  @override
  int sizeHint(RelayParentInfo obj) {
    int size = 0;
    size = size + const _i2.H256Codec().sizeHint(obj.relayParent);
    size = size + const _i2.H256Codec().sizeHint(obj.stateRoot);
    size = size + const _i3.BTreeMapCodec().sizeHint(obj.claimQueue);
    return size;
  }
}
