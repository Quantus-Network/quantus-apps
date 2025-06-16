// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// User is not allowed to make a call on behalf of this account
  notAllowed('NotAllowed', 0),

  /// Threshold must be greater than zero
  zeroThreshold('ZeroThreshold', 1),

  /// Friends list must be greater than zero and threshold
  notEnoughFriends('NotEnoughFriends', 2),

  /// Friends list must be less than max friends
  maxFriends('MaxFriends', 3),

  /// Friends list must be sorted and free of duplicates
  notSorted('NotSorted', 4),

  /// This account is not set up for recovery
  notRecoverable('NotRecoverable', 5),

  /// This account is already set up for recovery
  alreadyRecoverable('AlreadyRecoverable', 6),

  /// A recovery process has already started for this account
  alreadyStarted('AlreadyStarted', 7),

  /// A recovery process has not started for this rescuer
  notStarted('NotStarted', 8),

  /// This account is not a friend who can vouch
  notFriend('NotFriend', 9),

  /// The friend must wait until the delay period to vouch for this recovery
  delayPeriod('DelayPeriod', 10),

  /// This user has already vouched for this recovery
  alreadyVouched('AlreadyVouched', 11),

  /// The threshold for recovering this account has not been met
  threshold('Threshold', 12),

  /// There are still active recovery attempts that need to be closed
  stillActive('StillActive', 13),

  /// This account is already set up for recovery
  alreadyProxy('AlreadyProxy', 14),

  /// Some internal state is broken.
  badState('BadState', 15);

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
        return Error.notAllowed;
      case 1:
        return Error.zeroThreshold;
      case 2:
        return Error.notEnoughFriends;
      case 3:
        return Error.maxFriends;
      case 4:
        return Error.notSorted;
      case 5:
        return Error.notRecoverable;
      case 6:
        return Error.alreadyRecoverable;
      case 7:
        return Error.alreadyStarted;
      case 8:
        return Error.notStarted;
      case 9:
        return Error.notFriend;
      case 10:
        return Error.delayPeriod;
      case 11:
        return Error.alreadyVouched;
      case 12:
        return Error.threshold;
      case 13:
        return Error.stillActive;
      case 14:
        return Error.alreadyProxy;
      case 15:
        return Error.badState;
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
