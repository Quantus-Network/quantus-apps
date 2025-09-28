// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// The account attempting to enable reversibility is already marked as reversible.
  accountAlreadyHighSecurity('AccountAlreadyHighSecurity', 0),

  /// The account attempting the action is not marked as high security.
  accountNotHighSecurity('AccountNotHighSecurity', 1),

  /// Interceptor can not be the account itself, because it is redundant.
  interceptorCannotBeSelf('InterceptorCannotBeSelf', 2),

  /// Recoverer cannot be the account itself, because it is redundant.
  recovererCannotBeSelf('RecovererCannotBeSelf', 3),

  /// The specified pending transaction ID was not found.
  pendingTxNotFound('PendingTxNotFound', 4),

  /// The caller is not the original submitter of the transaction they are trying to cancel.
  notOwner('NotOwner', 5),

  /// The account has reached the maximum number of pending reversible transactions.
  tooManyPendingTransactions('TooManyPendingTransactions', 6),

  /// The specified delay period is below the configured minimum.
  delayTooShort('DelayTooShort', 7),

  /// Failed to schedule the transaction execution with the scheduler pallet.
  schedulingFailed('SchedulingFailed', 8),

  /// Failed to cancel the scheduled task with the scheduler pallet.
  cancellationFailed('CancellationFailed', 9),

  /// Failed to decode the OpaqueCall back into a RuntimeCall.
  callDecodingFailed('CallDecodingFailed', 10),

  /// Call is invalid.
  invalidCall('InvalidCall', 11),

  /// Invalid scheduler origin
  invalidSchedulerOrigin('InvalidSchedulerOrigin', 12),

  /// Reverser is invalid
  invalidReverser('InvalidReverser', 13),

  /// Cannot schedule one time reversible transaction when account is reversible (theft deterrence)
  accountAlreadyReversibleCannotScheduleOneTime(
      'AccountAlreadyReversibleCannotScheduleOneTime', 14),

  /// The interceptor has reached the maximum number of accounts they can intercept for.
  tooManyInterceptorAccounts('TooManyInterceptorAccounts', 15);

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
        return Error.accountAlreadyHighSecurity;
      case 1:
        return Error.accountNotHighSecurity;
      case 2:
        return Error.interceptorCannotBeSelf;
      case 3:
        return Error.recovererCannotBeSelf;
      case 4:
        return Error.pendingTxNotFound;
      case 5:
        return Error.notOwner;
      case 6:
        return Error.tooManyPendingTransactions;
      case 7:
        return Error.delayTooShort;
      case 8:
        return Error.schedulingFailed;
      case 9:
        return Error.cancellationFailed;
      case 10:
        return Error.callDecodingFailed;
      case 11:
        return Error.invalidCall;
      case 12:
        return Error.invalidSchedulerOrigin;
      case 13:
        return Error.invalidReverser;
      case 14:
        return Error.accountAlreadyReversibleCannotScheduleOneTime;
      case 15:
        return Error.tooManyInterceptorAccounts;
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
