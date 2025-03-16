// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// The account cannot perform this operation.
  notAllowed('NotAllowed', 0),

  /// An existing staker cannot perform this action.
  alreadyStaking('AlreadyStaking', 1),

  /// Reward Destination cannot be same as `Agent` account.
  invalidRewardDestination('InvalidRewardDestination', 2),

  /// Delegation conditions are not met.
  ///
  /// Possible issues are
  /// 1) Cannot delegate to self,
  /// 2) Cannot delegate to multiple delegates.
  invalidDelegation('InvalidDelegation', 3),

  /// The account does not have enough funds to perform the operation.
  notEnoughFunds('NotEnoughFunds', 4),

  /// Not an existing `Agent` account.
  notAgent('NotAgent', 5),

  /// Not a Delegator account.
  notDelegator('NotDelegator', 6),

  /// Some corruption in internal state.
  badState('BadState', 7),

  /// Unapplied pending slash restricts operation on `Agent`.
  unappliedSlash('UnappliedSlash', 8),

  /// `Agent` has no pending slash to be applied.
  nothingToSlash('NothingToSlash', 9),

  /// Failed to withdraw amount from Core Staking.
  withdrawFailed('WithdrawFailed', 10),

  /// Operation not supported by this pallet.
  notSupported('NotSupported', 11);

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
        return Error.alreadyStaking;
      case 2:
        return Error.invalidRewardDestination;
      case 3:
        return Error.invalidDelegation;
      case 4:
        return Error.notEnoughFunds;
      case 5:
        return Error.notAgent;
      case 6:
        return Error.notDelegator;
      case 7:
        return Error.badState;
      case 8:
        return Error.unappliedSlash;
      case 9:
        return Error.nothingToSlash;
      case 10:
        return Error.withdrawFailed;
      case 11:
        return Error.notSupported;
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
