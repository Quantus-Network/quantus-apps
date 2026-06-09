// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i3;

import 'package:polkadart/scale_codec.dart' as _i1;

import '../qp_scheduler/block_number_or_timestamp.dart' as _i2;

class RetryConfig {
  const RetryConfig({
    required this.totalRetries,
    required this.remaining,
    required this.period,
  });

  factory RetryConfig.decode(_i1.Input input) {
    return codec.decode(input);
  }

  /// u8
  final int totalRetries;

  /// u8
  final int remaining;

  /// Period
  final _i2.BlockNumberOrTimestamp period;

  static const $RetryConfigCodec codec = $RetryConfigCodec();

  _i3.Uint8List encode() {
    return codec.encode(this);
  }

  Map<String, dynamic> toJson() => {
        'totalRetries': totalRetries,
        'remaining': remaining,
        'period': period.toJson(),
      };

  @override
  bool operator ==(Object other) =>
      identical(
        this,
        other,
      ) ||
      other is RetryConfig &&
          other.totalRetries == totalRetries &&
          other.remaining == remaining &&
          other.period == period;

  @override
  int get hashCode => Object.hash(
        totalRetries,
        remaining,
        period,
      );
}

class $RetryConfigCodec with _i1.Codec<RetryConfig> {
  const $RetryConfigCodec();

  @override
  void encodeTo(
    RetryConfig obj,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      obj.totalRetries,
      output,
    );
    _i1.U8Codec.codec.encodeTo(
      obj.remaining,
      output,
    );
    _i2.BlockNumberOrTimestamp.codec.encodeTo(
      obj.period,
      output,
    );
  }

  @override
  RetryConfig decode(_i1.Input input) {
    return RetryConfig(
      totalRetries: _i1.U8Codec.codec.decode(input),
      remaining: _i1.U8Codec.codec.decode(input),
      period: _i2.BlockNumberOrTimestamp.codec.decode(input),
    );
  }

  @override
  int sizeHint(RetryConfig obj) {
    int size = 0;
    size = size + _i1.U8Codec.codec.sizeHint(obj.totalRetries);
    size = size + _i1.U8Codec.codec.sizeHint(obj.remaining);
    size = size + _i2.BlockNumberOrTimestamp.codec.sizeHint(obj.period);
    return size;
  }
}
