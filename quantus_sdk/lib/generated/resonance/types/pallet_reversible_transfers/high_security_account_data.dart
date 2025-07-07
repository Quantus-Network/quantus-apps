// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i4;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i5;

import '../qp_scheduler/block_number_or_timestamp.dart' as _i3;
import '../sp_core/crypto/account_id32.dart' as _i2;

class HighSecurityAccountData {
  const HighSecurityAccountData({
    required this.interceptor,
    required this.recoverer,
    required this.delay,
  });

  factory HighSecurityAccountData.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// AccountId
  final _i2.AccountId32 interceptor;

  /// AccountId
  final _i2.AccountId32 recoverer;

  /// Delay
  final _i3.BlockNumberOrTimestamp delay;

  static const $HighSecurityAccountDataCodec codec =
      $HighSecurityAccountDataCodec();

  _i4.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'interceptor': interceptor.toList(),
        'recoverer': recoverer.toList(),
        'delay': delay.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is HighSecurityAccountData &&
          _i5.listsEqual(
            other.interceptor,
            interceptor,
          ) &&
          _i5.listsEqual(
            other.recoverer,
            recoverer,
          ) &&
          other.delay == delay;

  @override
  int get hashCode => Object.hash(
        interceptor,
        recoverer,
        delay,
      );
}

class $HighSecurityAccountDataCodec with _i1.Codec<HighSecurityAccountData> {
  const $HighSecurityAccountDataCodec();

  @override
  void encodeTo(
    HighSecurityAccountData obj,
    _i1.Output output,
  ) {
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.interceptor,
      output,
    );
    const _i1.U8ArrayCodec(32).encodeTo(
      obj.recoverer,
      output,
    );
    _i3.BlockNumberOrTimestamp.codec.encodeTo(
      obj.delay,
      output,
    );
  }

  @override
  HighSecurityAccountData decode(_i1.Input input) {
    return HighSecurityAccountData(
      interceptor: const _i1.U8ArrayCodec(32).decode(input),
      recoverer: const _i1.U8ArrayCodec(32).decode(input),
      delay: _i3.BlockNumberOrTimestamp.codec.decode(input),
    );
  }

  @override
  int sizeHint(HighSecurityAccountData obj) {
    int size = 0;
    size = size + const _i2.AccountId32Codec().sizeHint(obj.interceptor);
    size = size + const _i2.AccountId32Codec().sizeHint(obj.recoverer);
    size = size + _i3.BlockNumberOrTimestamp.codec.sizeHint(obj.delay);
    return size;
  }
}
