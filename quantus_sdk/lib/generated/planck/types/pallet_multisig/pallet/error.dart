// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// Not enough signers provided
  /// Multisig requires at least 2 unique signers
  notEnoughSigners('NotEnoughSigners', 0),

  /// Threshold must be greater than zero
  thresholdZero('ThresholdZero', 1),

  /// Threshold exceeds number of signers
  thresholdTooHigh('ThresholdTooHigh', 2),

  /// Too many signers
  tooManySigners('TooManySigners', 3),

  /// Multisig already exists
  multisigAlreadyExists('MultisigAlreadyExists', 4),

  /// Multisig not found
  multisigNotFound('MultisigNotFound', 5),

  /// Caller is not a signer of this multisig
  notASigner('NotASigner', 6),

  /// Proposal not found
  proposalNotFound('ProposalNotFound', 7),

  /// Caller is not the proposer
  notProposer('NotProposer', 8),

  /// Already approved by this signer
  alreadyApproved('AlreadyApproved', 9),

  /// Not enough approvals to execute
  notEnoughApprovals('NotEnoughApprovals', 10),

  /// Proposal expiry is in the past
  expiryInPast('ExpiryInPast', 11),

  /// Proposal expiry is too far in the future (exceeds MaxExpiryDuration)
  expiryTooFar('ExpiryTooFar', 12),

  /// Proposal has expired
  proposalExpired('ProposalExpired', 13),

  /// Failed to decode call data
  invalidCall('InvalidCall', 14),

  /// Too many total proposals in storage for this multisig (cleanup required)
  tooManyProposalsInStorage('TooManyProposalsInStorage', 15),

  /// This signer has too many proposals in storage (filibuster protection)
  tooManyProposalsPerSigner('TooManyProposalsPerSigner', 16),

  /// Insufficient balance for deposit
  insufficientBalance('InsufficientBalance', 17),

  /// Proposal has active deposit
  proposalHasDeposit('ProposalHasDeposit', 18),

  /// Proposal has not expired yet
  proposalNotExpired('ProposalNotExpired', 19),

  /// Proposal is not in a cancellable state (must be Active or Approved)
  proposalNotActive('ProposalNotActive', 20),

  /// Proposal has not been approved yet (threshold not reached)
  proposalNotApproved('ProposalNotApproved', 21),

  /// Call is not allowed for high-security multisig
  callNotAllowedForHighSecurityMultisig('CallNotAllowedForHighSecurityMultisig', 22),

  /// Proposal nonce exhausted (u32::MAX reached)
  proposalNonceExhausted('ProposalNonceExhausted', 23),

  /// Call weight exceeds MaxInnerCallWeight limit
  callWeightExceedsLimit('CallWeightExceedsLimit', 24);

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
        return Error.notEnoughSigners;
      case 1:
        return Error.thresholdZero;
      case 2:
        return Error.thresholdTooHigh;
      case 3:
        return Error.tooManySigners;
      case 4:
        return Error.multisigAlreadyExists;
      case 5:
        return Error.multisigNotFound;
      case 6:
        return Error.notASigner;
      case 7:
        return Error.proposalNotFound;
      case 8:
        return Error.notProposer;
      case 9:
        return Error.alreadyApproved;
      case 10:
        return Error.notEnoughApprovals;
      case 11:
        return Error.expiryInPast;
      case 12:
        return Error.expiryTooFar;
      case 13:
        return Error.proposalExpired;
      case 14:
        return Error.invalidCall;
      case 15:
        return Error.tooManyProposalsInStorage;
      case 16:
        return Error.tooManyProposalsPerSigner;
      case 17:
        return Error.insufficientBalance;
      case 18:
        return Error.proposalHasDeposit;
      case 19:
        return Error.proposalNotExpired;
      case 20:
        return Error.proposalNotActive;
      case 21:
        return Error.proposalNotApproved;
      case 22:
        return Error.callNotAllowedForHighSecurityMultisig;
      case 23:
        return Error.proposalNonceExhausted;
      case 24:
        return Error.callWeightExceedsLimit;
      default:
        throw Exception('Error: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Error value, _i1.Output output) {
    _i1.U8Codec.codec.encodeTo(value.codecIndex, output);
  }
}
