// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// Account is already a member.
  alreadyMember('AlreadyMember', 0),

  /// Account is not a member.
  notMember('NotMember', 1),

  /// The given poll index is unknown or has closed.
  notPolling('NotPolling', 2),

  /// The given poll is still ongoing.
  ongoing('Ongoing', 3),

  /// There are no further records to be removed.
  noneRemaining('NoneRemaining', 4),

  /// Unexpected error in state.
  corruption('Corruption', 5),

  /// The member's rank is too low to vote.
  rankTooLow('RankTooLow', 6),

  /// The information provided is incorrect.
  invalidWitness('InvalidWitness', 7),

  /// The origin is not sufficiently privileged to do the operation.
  noPermission('NoPermission', 8),

  /// The new member to exchange is the same as the old member
  sameMember('SameMember', 9),

  /// The max member count for the rank has been reached.
  tooManyMembers('TooManyMembers', 10);

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
        return Error.alreadyMember;
      case 1:
        return Error.notMember;
      case 2:
        return Error.notPolling;
      case 3:
        return Error.ongoing;
      case 4:
        return Error.noneRemaining;
      case 5:
        return Error.corruption;
      case 6:
        return Error.rankTooLow;
      case 7:
        return Error.invalidWitness;
      case 8:
        return Error.noPermission;
      case 9:
        return Error.sameMember;
      case 10:
        return Error.tooManyMembers;
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
