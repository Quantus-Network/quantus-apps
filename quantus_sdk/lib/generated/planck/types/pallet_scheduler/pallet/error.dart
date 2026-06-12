// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// Failed to schedule a call
  failedToSchedule('FailedToSchedule', 0),

  /// Cannot find the scheduled call.
  notFound('NotFound', 1),

  /// Given target block number is in the past.
  targetBlockNumberInPast('TargetBlockNumberInPast', 2),

  /// Given target timestamp is in the past.
  targetTimestampInPast('TargetTimestampInPast', 3),

  /// Reschedule failed because it does not change scheduled time.
  rescheduleNoChange('RescheduleNoChange', 4),

  /// Attempt to use a non-named function on a named task.
  named('Named', 5),

  /// Periodic scheduling is not supported.
  periodicNotSupported('PeriodicNotSupported', 6),

  /// Retry period type does not match task scheduling type.
  ///
  /// Block-scheduled tasks require a block-number retry period,
  /// and timestamp-scheduled tasks require a timestamp retry period.
  retryPeriodMismatch('RetryPeriodMismatch', 7);

  const Error(this.variantName, this.codecIndex);

  factory Error.decode(_i1.Input input) {
    return codec.decode(input);
  }

  final String variantName;

  final int codecIndex;

  static const $ErrorCodec codec = $ErrorCodec();

  String toJson() => variantName;

  _i2.Uint8List encode() {
    return codec.encode(this);
  }
}

class $ErrorCodec with _i1.Codec<Error> {
  const $ErrorCodec();

  @override
  Error decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return Error.failedToSchedule;
      case 1:
        return Error.notFound;
      case 2:
        return Error.targetBlockNumberInPast;
      case 3:
        return Error.targetTimestampInPast;
      case 4:
        return Error.rescheduleNoChange;
      case 5:
        return Error.named;
      case 6:
        return Error.periodicNotSupported;
      case 7:
        return Error.retryPeriodMismatch;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
