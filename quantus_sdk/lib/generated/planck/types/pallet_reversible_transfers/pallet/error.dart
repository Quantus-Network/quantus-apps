// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// The account attempting to enable reversibility is already marked as reversible.
  accountAlreadyHighSecurity('AccountAlreadyHighSecurity', 0),

  /// The account attempting the action is not marked as high security.
  accountNotHighSecurity('AccountNotHighSecurity', 1),

  /// Guardian cannot be the account itself, because it is redundant.
  guardianCannotBeSelf('GuardianCannotBeSelf', 2),

  /// The specified pending transaction ID was not found.
  pendingTxNotFound('PendingTxNotFound', 3),

  /// The caller is not the original submitter of the transaction they are trying to cancel.
  notOwner('NotOwner', 4),

  /// The account has reached the maximum number of pending reversible transactions.
  tooManyPendingTransactions('TooManyPendingTransactions', 5),

  /// The specified delay period is below the configured minimum.
  delayTooShort('DelayTooShort', 6),

  /// Failed to schedule the transaction execution with the scheduler pallet.
  schedulingFailed('SchedulingFailed', 7),

  /// Failed to cancel the scheduled task with the scheduler pallet.
  cancellationFailed('CancellationFailed', 8),

  /// Call is invalid.
  invalidCall('InvalidCall', 9),

  /// Invalid scheduler origin
  invalidSchedulerOrigin('InvalidSchedulerOrigin', 10),

  /// Reverser is invalid
  invalidReverser('InvalidReverser', 11),

  /// Cannot schedule one time reversible transaction when account is reversible (theft
  /// deterrence)
  accountAlreadyReversibleCannotScheduleOneTime('AccountAlreadyReversibleCannotScheduleOneTime', 12),

  /// Asset transfers are not supported.
  assetsNotSupported('AssetsNotSupported', 13),

  /// Zero-amount transfers cannot be scheduled: there is nothing to hold,
  /// execute, or reverse.
  zeroAmount('ZeroAmount', 14);

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
        return Error.accountAlreadyHighSecurity;
      case 1:
        return Error.accountNotHighSecurity;
      case 2:
        return Error.guardianCannotBeSelf;
      case 3:
        return Error.pendingTxNotFound;
      case 4:
        return Error.notOwner;
      case 5:
        return Error.tooManyPendingTransactions;
      case 6:
        return Error.delayTooShort;
      case 7:
        return Error.schedulingFailed;
      case 8:
        return Error.cancellationFailed;
      case 9:
        return Error.invalidCall;
      case 10:
        return Error.invalidSchedulerOrigin;
      case 11:
        return Error.invalidReverser;
      case 12:
        return Error.accountAlreadyReversibleCannotScheduleOneTime;
      case 13:
        return Error.assetsNotSupported;
      case 14:
        return Error.zeroAmount;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
