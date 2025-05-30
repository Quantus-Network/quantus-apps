// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../../sp_runtime/multiaddress/multi_address.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

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

class $Call {
  const $Call();

  MintNewTokens mintNewTokens({
    required _i3.MultiAddress dest,
    required BigInt seed,
  }) {
    return MintNewTokens(
      dest: dest,
      seed: seed,
    );
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return MintNewTokens._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Call value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case MintNewTokens:
        (value as MintNewTokens).encodeTo(output);
        break;
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case MintNewTokens:
        return (value as MintNewTokens)._sizeHint();
      default:
        throw Exception(
            'Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// mint new tokens
class MintNewTokens extends Call {
  const MintNewTokens({
    required this.dest,
    required this.seed,
  });

  factory MintNewTokens._decode(_i1.Input input) {
    return MintNewTokens(
      dest: _i3.MultiAddress.codec.decode(input),
      seed: _i1.U64Codec.codec.decode(input),
    );
  }

  /// <T::Lookup as StaticLookup>::Source
  final _i3.MultiAddress dest;

  /// u64
  final BigInt seed;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
        'mint_new_tokens': {
          'dest': dest.toJson(),
          'seed': seed,
        }
      };

  int _sizeHint() {
    int size = 1;
    size = size + _i3.MultiAddress.codec.sizeHint(dest);
    size = size + _i1.U64Codec.codec.sizeHint(seed);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
    _i3.MultiAddress.codec.encodeTo(
      dest,
      output,
    );
    _i1.U64Codec.codec.encodeTo(
      seed,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is MintNewTokens && other.dest == dest && other.seed == seed;

  @override
  int get hashCode => Object.hash(
        dest,
        seed,
      );
}
