// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i3;

/// The `Event` enum of this pallet
abstract class Event {
  const Event();

  factory Event.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $EventCodec codec = $EventCodec();

  static const $Event values = $Event();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, dynamic>> toJson();
}

class $Event {
  const $Event();

  LeafInserted leafInserted({required BigInt index, required List<int> leafHash, required List<int> newRoot}) {
    return LeafInserted(index: index, leafHash: leafHash, newRoot: newRoot);
  }

  TreeGrew treeGrew({required int newDepth}) {
    return TreeGrew(newDepth: newDepth);
  }
}

class $EventCodec with _i1.Codec<Event> {
  const $EventCodec();

  @override
  Event decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return LeafInserted._decode(input);
      case 1:
        return TreeGrew._decode(input);
      default:
        throw Exception('Event: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Event value, _i1.Output output) {
    switch (value.runtimeType) {
      case LeafInserted:
        (value as LeafInserted).encodeTo(output);
        break;
      case TreeGrew:
        (value as TreeGrew).encodeTo(output);
        break;
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Event value) {
    switch (value.runtimeType) {
      case LeafInserted:
        return (value as LeafInserted)._sizeHint();
      case TreeGrew:
        return (value as TreeGrew)._sizeHint();
      default:
        throw Exception('Event: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// A new leaf was inserted into the tree.
class LeafInserted extends Event {
  const LeafInserted({required this.index, required this.leafHash, required this.newRoot});

  factory LeafInserted._decode(_i1.Input input) {
    return LeafInserted(
      index: _i1.U64Codec.codec.decode(input),
      leafHash: const _i1.U8ArrayCodec(32).decode(input),
      newRoot: const _i1.U8ArrayCodec(32).decode(input),
    );
  }

  /// u64
  final BigInt index;

  /// Hash256
  final List<int> leafHash;

  /// Hash256
  final List<int> newRoot;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'LeafInserted': {'index': index, 'leafHash': leafHash.toList(), 'newRoot': newRoot.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(index);
    size = size + const _i1.U8ArrayCodec(32).sizeHint(leafHash);
    size = size + const _i1.U8ArrayCodec(32).sizeHint(newRoot);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i1.U64Codec.codec.encodeTo(index, output);
    const _i1.U8ArrayCodec(32).encodeTo(leafHash, output);
    const _i1.U8ArrayCodec(32).encodeTo(newRoot, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeafInserted &&
          other.index == index &&
          _i3.listsEqual(other.leafHash, leafHash) &&
          _i3.listsEqual(other.newRoot, newRoot);

  @override
  int get hashCode => Object.hash(index, leafHash, newRoot);
}

/// Tree depth increased.
class TreeGrew extends Event {
  const TreeGrew({required this.newDepth});

  factory TreeGrew._decode(_i1.Input input) {
    return TreeGrew(newDepth: _i1.U8Codec.codec.decode(input));
  }

  /// u8
  final int newDepth;

  @override
  Map<String, Map<String, int>> toJson() => {
    'TreeGrew': {'newDepth': newDepth},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U8Codec.codec.sizeHint(newDepth);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    _i1.U8Codec.codec.encodeTo(newDepth, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is TreeGrew && other.newDepth == newDepth;

  @override
  int get hashCode => newDepth.hashCode;
}
