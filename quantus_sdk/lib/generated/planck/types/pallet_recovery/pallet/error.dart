// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// User is not allowed to make a call on behalf of this account
  notAllowed('NotAllowed', 0),

  /// Call is not allowed for a high-security account
  callNotAllowedForHighSecurity('CallNotAllowedForHighSecurity', 1),

  /// Threshold must be greater than zero
  zeroThreshold('ZeroThreshold', 2),

  /// Friends list must be greater than zero and threshold
  notEnoughFriends('NotEnoughFriends', 3),

  /// Friends list must be less than max friends
  maxFriends('MaxFriends', 4),

  /// Friends list must be sorted and free of duplicates
  notSorted('NotSorted', 5),

  /// This account is not set up for recovery
  notRecoverable('NotRecoverable', 6),

  /// This account is already set up for recovery
  alreadyRecoverable('AlreadyRecoverable', 7),

  /// A recovery process has already started for this account
  alreadyStarted('AlreadyStarted', 8),

  /// A recovery process has not started for this rescuer
  notStarted('NotStarted', 9),

  /// This account is not a friend who can vouch
  notFriend('NotFriend', 10),

  /// The friend must wait until the delay period to vouch for this recovery
  delayPeriod('DelayPeriod', 11),

  /// This user has already vouched for this recovery
  alreadyVouched('AlreadyVouched', 12),

  /// The threshold for recovering this account has not been met
  threshold('Threshold', 13),

  /// There are still active recovery attempts that need to be closed
  stillActive('StillActive', 14),

  /// This account is already set up for recovery
  alreadyProxy('AlreadyProxy', 15),

  /// Some internal state is broken.
  badState('BadState', 16);

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
        return Error.notAllowed;
      case 1:
        return Error.callNotAllowedForHighSecurity;
      case 2:
        return Error.zeroThreshold;
      case 3:
        return Error.notEnoughFriends;
      case 4:
        return Error.maxFriends;
      case 5:
        return Error.notSorted;
      case 6:
        return Error.notRecoverable;
      case 7:
        return Error.alreadyRecoverable;
      case 8:
        return Error.alreadyStarted;
      case 9:
        return Error.notStarted;
      case 10:
        return Error.notFriend;
      case 11:
        return Error.delayPeriod;
      case 12:
        return Error.alreadyVouched;
      case 13:
        return Error.threshold;
      case 14:
        return Error.stillActive;
      case 15:
        return Error.alreadyProxy;
      case 16:
        return Error.badState;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
