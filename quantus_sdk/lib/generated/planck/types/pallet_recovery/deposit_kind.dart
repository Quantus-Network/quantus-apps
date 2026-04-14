// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../sp_core/crypto/account_id32.dart' as _i3;

abstract class DepositKind {
  const DepositKind();

  factory DepositKind.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $DepositKindCodec codec = $DepositKindCodec();

  static const $DepositKind values = $DepositKind();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, dynamic> toJson();
}

class $DepositKind {
  const $DepositKind();

  RecoveryConfig recoveryConfig() {
    return RecoveryConfig();
  }

  ActiveRecoveryFor activeRecoveryFor(_i3.AccountId32 value0) {
    return ActiveRecoveryFor(value0);
  }
}

class $DepositKindCodec with _i1.Codec<DepositKind> {
  const $DepositKindCodec();

  @override
  DepositKind decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return const RecoveryConfig();
      case 1:
        return ActiveRecoveryFor._decode(input);
      default:
        throw Exception('DepositKind: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    DepositKind value,
    _i1.Output output,
  ) {
    switch (value.runtimeType) {
      case RecoveryConfig:
        (value as RecoveryConfig).encodeTo(output);
        break;
      case ActiveRecoveryFor:
        (value as ActiveRecoveryFor).encodeTo(output);
        break;
      default:
        throw Exception(
            'DepositKind: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(DepositKind value) {
    switch (value.runtimeType) {
      case RecoveryConfig:
        return 1;
      case ActiveRecoveryFor:
        return (value as ActiveRecoveryFor)._sizeHint();
      default:
        throw Exception(
            'DepositKind: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

class RecoveryConfig extends DepositKind {
  const RecoveryConfig();

  @override
  Map<String, dynamic> toJson() => {'RecoveryConfig': null};

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      0,
      output,
    );
  }

  @override
  bool operator ==(Object other) => other is RecoveryConfig;

  @override
  int get hashCode => runtimeType.hashCode;
}

class ActiveRecoveryFor extends DepositKind {
  const ActiveRecoveryFor(this.value0);

  factory ActiveRecoveryFor._decode(_i1.Input input) {
    return ActiveRecoveryFor(const _i1.U8ArrayCodec(32).decode(input));
  }

  /// <T as frame_system::Config>::AccountId
  final _i3.AccountId32 value0;

  @override
  Map<String, List<int>> toJson() => {'ActiveRecoveryFor': value0.toList()};

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(value0);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(
      1,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      value0,
      output,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is ActiveRecoveryFor &&
          _i4.listsEqual(
            other.value0,
            value0,
          );

  @override
  int get hashCode => value0.hashCode;
}
