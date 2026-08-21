// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// No schedule exists under this id.
  noSchedule('NoSchedule', 0),

  /// Schedule parameters violate `start <= cliff <= end`, `start < end`,
  /// `total >= MinimumPayout`, or `total` is not a multiple of the payout
  /// quantum.
  invalidSchedule('InvalidSchedule', 1),

  /// Nothing is claimable right now (before the cliff, already fully claimed, or
  /// less than the minimum payout accrued).
  nothingToClaim('NothingToClaim', 2),

  /// This schedule has already paid out within the minimum claim interval.
  claimTooSoon('ClaimTooSoon', 3),

  /// Paying now would leave a remainder below the minimum payout; wait until the
  /// entire remainder has vested.
  claimWouldLeaveDust('ClaimWouldLeaveDust', 4),

  /// Ending now would emit a non-zero beneficiary payout below the minimum.
  payoutBelowMinimum('PayoutBelowMinimum', 5),

  /// The treasury account is not configured or aliases the vesting pot.
  treasuryNotConfigured('TreasuryNotConfigured', 6),

  /// The pot does not hold its existential-deposit buffer; endow it first.
  potUnderfunded('PotUnderfunded', 7),

  /// The beneficiary must not be the pot, and retargeting must change the account.
  invalidBeneficiary('InvalidBeneficiary', 8),

  /// The proof recorder reported the payout credit as dropped: no wormhole leaf
  /// was created, so the payout is rolled back rather than finalized without the
  /// proof material a keyless beneficiary needs to exit.
  payoutProofNotRecorded('PayoutProofNotRecorded', 9);

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
        return Error.noSchedule;
      case 1:
        return Error.invalidSchedule;
      case 2:
        return Error.nothingToClaim;
      case 3:
        return Error.claimTooSoon;
      case 4:
        return Error.claimWouldLeaveDust;
      case 5:
        return Error.payoutBelowMinimum;
      case 6:
        return Error.treasuryNotConfigured;
      case 7:
        return Error.potUnderfunded;
      case 8:
        return Error.invalidBeneficiary;
      case 9:
        return Error.payoutProofNotRecorded;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
