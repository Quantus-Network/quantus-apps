// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// The account attempting to enable reversibility is already marked as reversible.
  accountAlreadyReversible('AccountAlreadyReversible', 0),

  /// The account attempting the action is not marked as reversible.
  accountNotReversible('AccountNotReversible', 1),

  /// The specified pending transaction ID was not found.
  pendingTxNotFound('PendingTxNotFound', 2),

  /// The caller is not the original submitter of the transaction they are trying to cancel.
  notOwner('NotOwner', 3),

  /// The account has reached the maximum number of pending reversible transactions.
  tooManyPendingTransactions('TooManyPendingTransactions', 4),

  /// The specified delay period is below the configured minimum.
  delayTooShort('DelayTooShort', 5),

  /// Failed to schedule the transaction execution with the scheduler pallet.
  schedulingFailed('SchedulingFailed', 6),

  /// Failed to cancel the scheduled task with the scheduler pallet.
  cancellationFailed('CancellationFailed', 7),

  /// Failed to decode the OpaqueCall back into a RuntimeCall.
  callDecodingFailed('CallDecodingFailed', 8),

  /// Call is invalid.
  invalidCall('InvalidCall', 9),

  /// Invalid scheduler origin
  invalidSchedulerOrigin('InvalidSchedulerOrigin', 10);

  const Error(
    this.variantName,
    this.codecIndex,
  );

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
        return Error.accountAlreadyReversible;
      case 1:
        return Error.accountNotReversible;
      case 2:
        return Error.pendingTxNotFound;
      case 3:
        return Error.notOwner;
      case 4:
        return Error.tooManyPendingTransactions;
      case 5:
        return Error.delayTooShort;
      case 6:
        return Error.schedulingFailed;
      case 7:
        return Error.cancellationFailed;
      case 8:
        return Error.callDecodingFailed;
      case 9:
        return Error.invalidCall;
      case 10:
        return Error.invalidSchedulerOrigin;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(
    Error value,
    _i1.Output output,
  ) {
    _i1.U8Codec.codec.encodeTo(
      value.codecIndex,
      output,
    );
  }
}
