// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

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

  LeafInserted leafInserted({required BigInt index}) {
    return LeafInserted(index: index);
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

/// A new leaf was inserted into the tree. The root including this leaf is
/// computed at the end of the block and published in the block header. The
/// leaf hash is deliberately not included: it is derivable from `Leaves`
/// (and served by the RPC), and hashing it here would double the per-leaf
/// Poseidon work the batched settlement saves.
class LeafInserted extends Event {
  const LeafInserted({required this.index});

  factory LeafInserted._decode(_i1.Input input) {
    return LeafInserted(index: _i1.U64Codec.codec.decode(input));
  }

  /// u64
  final BigInt index;

  @override
  Map<String, Map<String, BigInt>> toJson() => {
    'LeafInserted': {'index': index},
  };

  int _sizeHint() {
    int size = 1;
    size = size + _i1.U64Codec.codec.sizeHint(index);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    _i1.U64Codec.codec.encodeTo(index, output);
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is LeafInserted && other.index == index;

  @override
  int get hashCode => index.hashCode;
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
