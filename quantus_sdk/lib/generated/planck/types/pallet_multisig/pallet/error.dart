// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;

/// The `Error` enum of this pallet.
enum Error {
  /// Not enough signers provided
  notEnoughSigners('NotEnoughSigners', 0),

  /// Threshold must be greater than zero
  thresholdZero('ThresholdZero', 1),

  /// Threshold exceeds number of signers
  thresholdTooHigh('ThresholdTooHigh', 2),

  /// Too many signers
  tooManySigners('TooManySigners', 3),

  /// Duplicate signer in list
  duplicateSigner('DuplicateSigner', 4),

  /// Multisig already exists
  multisigAlreadyExists('MultisigAlreadyExists', 5),

  /// Multisig not found
  multisigNotFound('MultisigNotFound', 6),

  /// Caller is not a signer of this multisig
  notASigner('NotASigner', 7),

  /// Proposal not found
  proposalNotFound('ProposalNotFound', 8),

  /// Caller is not the proposer
  notProposer('NotProposer', 9),

  /// Already approved by this signer
  alreadyApproved('AlreadyApproved', 10),

  /// Not enough approvals to execute
  notEnoughApprovals('NotEnoughApprovals', 11),

  /// Proposal expiry is in the past
  expiryInPast('ExpiryInPast', 12),

  /// Proposal expiry is too far in the future (exceeds MaxExpiryDuration)
  expiryTooFar('ExpiryTooFar', 13),

  /// Proposal has expired
  proposalExpired('ProposalExpired', 14),

  /// Call data too large
  callTooLarge('CallTooLarge', 15),

  /// Failed to decode call data
  invalidCall('InvalidCall', 16),

  /// Too many total proposals in storage for this multisig (cleanup required)
  tooManyProposalsInStorage('TooManyProposalsInStorage', 17),

  /// This signer has too many proposals in storage (filibuster protection)
  tooManyProposalsPerSigner('TooManyProposalsPerSigner', 18),

  /// Insufficient balance for deposit
  insufficientBalance('InsufficientBalance', 19),

  /// Proposal has active deposit
  proposalHasDeposit('ProposalHasDeposit', 20),

  /// Proposal has not expired yet
  proposalNotExpired('ProposalNotExpired', 21),

  /// Proposal is not active (already executed or cancelled)
  proposalNotActive('ProposalNotActive', 22),

  /// Proposal has not been approved yet (threshold not reached)
  proposalNotApproved('ProposalNotApproved', 23),

  /// Cannot dissolve multisig with existing proposals (clear them first)
  proposalsExist('ProposalsExist', 24),

  /// Multisig account must have zero balance before dissolution
  multisigAccountNotZero('MultisigAccountNotZero', 25),

  /// Call is not allowed for high-security multisig
  callNotAllowedForHighSecurityMultisig(
      'CallNotAllowedForHighSecurityMultisig', 26);

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
        return Error.notEnoughSigners;
      case 1:
        return Error.thresholdZero;
      case 2:
        return Error.thresholdTooHigh;
      case 3:
        return Error.tooManySigners;
      case 4:
        return Error.duplicateSigner;
      case 5:
        return Error.multisigAlreadyExists;
      case 6:
        return Error.multisigNotFound;
      case 7:
        return Error.notASigner;
      case 8:
        return Error.proposalNotFound;
      case 9:
        return Error.notProposer;
      case 10:
        return Error.alreadyApproved;
      case 11:
        return Error.notEnoughApprovals;
      case 12:
        return Error.expiryInPast;
      case 13:
        return Error.expiryTooFar;
      case 14:
        return Error.proposalExpired;
      case 15:
        return Error.callTooLarge;
      case 16:
        return Error.invalidCall;
      case 17:
        return Error.tooManyProposalsInStorage;
      case 18:
        return Error.tooManyProposalsPerSigner;
      case 19:
        return Error.insufficientBalance;
      case 20:
        return Error.proposalHasDeposit;
      case 21:
        return Error.proposalNotExpired;
      case 22:
        return Error.proposalNotActive;
      case 23:
        return Error.proposalNotApproved;
      case 24:
        return Error.proposalsExist;
      case 25:
        return Error.multisigAccountNotZero;
      case 26:
        return Error.callNotAllowedForHighSecurityMultisig;
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
