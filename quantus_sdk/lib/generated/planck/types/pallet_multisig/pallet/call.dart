// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:typed_data' as _i2;

import 'package:polkadart/scale_codec.dart' as _i1;
import 'package:quiver/collection.dart' as _i4;

import '../../sp_core/crypto/account_id32.dart' as _i3;

/// Contains a variant per dispatchable extrinsic that this pallet has.
abstract class Call {
  const Call();

  factory Call.decode(_i1.Input input) {
    return codec.decode(input);
  }

  static const $CallCodec codec = $CallCodec();

  static const $Call values = $Call();

  _i2.Uint8List encode() {
    final output = _i1.ByteOutput(codec.sizeHint(this));
    codec.encodeTo(this, output);
    return output.toBytes();
  }

  int sizeHint() {
    return codec.sizeHint(this);
  }

  Map<String, Map<String, dynamic>> toJson();
}

class $Call {
  const $Call();

  CreateMultisig createMultisig({
    required List<_i3.AccountId32> signers,
    required int threshold,
    required BigInt nonce,
  }) {
    return CreateMultisig(signers: signers, threshold: threshold, nonce: nonce);
  }

  Propose propose({required _i3.AccountId32 multisigAddress, required List<int> call, required int expiry}) {
    return Propose(multisigAddress: multisigAddress, call: call, expiry: expiry);
  }

  Approve approve({required _i3.AccountId32 multisigAddress, required int proposalId}) {
    return Approve(multisigAddress: multisigAddress, proposalId: proposalId);
  }

  Cancel cancel({required _i3.AccountId32 multisigAddress, required int proposalId}) {
    return Cancel(multisigAddress: multisigAddress, proposalId: proposalId);
  }

  RemoveExpired removeExpired({required _i3.AccountId32 multisigAddress, required int proposalId}) {
    return RemoveExpired(multisigAddress: multisigAddress, proposalId: proposalId);
  }

  ClaimDeposits claimDeposits({required _i3.AccountId32 multisigAddress}) {
    return ClaimDeposits(multisigAddress: multisigAddress);
  }

  Execute execute({required _i3.AccountId32 multisigAddress, required int proposalId}) {
    return Execute(multisigAddress: multisigAddress, proposalId: proposalId);
  }

  ApproveDissolve approveDissolve({required _i3.AccountId32 multisigAddress}) {
    return ApproveDissolve(multisigAddress: multisigAddress);
  }
}

class $CallCodec with _i1.Codec<Call> {
  const $CallCodec();

  @override
  Call decode(_i1.Input input) {
    final index = _i1.U8Codec.codec.decode(input);
    switch (index) {
      case 0:
        return CreateMultisig._decode(input);
      case 1:
        return Propose._decode(input);
      case 2:
        return Approve._decode(input);
      case 3:
        return Cancel._decode(input);
      case 4:
        return RemoveExpired._decode(input);
      case 5:
        return ClaimDeposits._decode(input);
      case 7:
        return Execute._decode(input);
      case 6:
        return ApproveDissolve._decode(input);
      default:
        throw Exception('Call: Invalid variant index: "$index"');
    }
  }

  @override
  void encodeTo(Call value, _i1.Output output) {
    switch (value.runtimeType) {
      case CreateMultisig:
        (value as CreateMultisig).encodeTo(output);
        break;
      case Propose:
        (value as Propose).encodeTo(output);
        break;
      case Approve:
        (value as Approve).encodeTo(output);
        break;
      case Cancel:
        (value as Cancel).encodeTo(output);
        break;
      case RemoveExpired:
        (value as RemoveExpired).encodeTo(output);
        break;
      case ClaimDeposits:
        (value as ClaimDeposits).encodeTo(output);
        break;
      case Execute:
        (value as Execute).encodeTo(output);
        break;
      case ApproveDissolve:
        (value as ApproveDissolve).encodeTo(output);
        break;
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }

  @override
  int sizeHint(Call value) {
    switch (value.runtimeType) {
      case CreateMultisig:
        return (value as CreateMultisig)._sizeHint();
      case Propose:
        return (value as Propose)._sizeHint();
      case Approve:
        return (value as Approve)._sizeHint();
      case Cancel:
        return (value as Cancel)._sizeHint();
      case RemoveExpired:
        return (value as RemoveExpired)._sizeHint();
      case ClaimDeposits:
        return (value as ClaimDeposits)._sizeHint();
      case Execute:
        return (value as Execute)._sizeHint();
      case ApproveDissolve:
        return (value as ApproveDissolve)._sizeHint();
      default:
        throw Exception('Call: Unsupported "$value" of type "${value.runtimeType}"');
    }
  }
}

/// Create a new multisig account with deterministic address
///
/// Parameters:
/// - `signers`: List of accounts that can sign for this multisig
/// - `threshold`: Number of approvals required to execute transactions
/// - `nonce`: User-provided nonce for address uniqueness
///
/// The multisig address is deterministically derived from:
/// hash(pallet_id || sorted_signers || threshold || nonce)
///
/// Signers are automatically sorted before hashing, so order doesn't matter.
///
/// Economic costs:
/// - MultisigFee: burned immediately (spam prevention)
/// - MultisigDeposit: reserved until dissolution, then returned to creator (storage bond)
class CreateMultisig extends Call {
  const CreateMultisig({required this.signers, required this.threshold, required this.nonce});

  factory CreateMultisig._decode(_i1.Input input) {
    return CreateMultisig(
      signers: const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).decode(input),
      threshold: _i1.U32Codec.codec.decode(input),
      nonce: _i1.U64Codec.codec.decode(input),
    );
  }

  /// Vec<T::AccountId>
  final List<_i3.AccountId32> signers;

  /// u32
  final int threshold;

  /// u64
  final BigInt nonce;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'create_multisig': {
      'signers': signers.map((value) => value.toList()).toList(),
      'threshold': threshold,
      'nonce': nonce,
    },
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).sizeHint(signers);
    size = size + _i1.U32Codec.codec.sizeHint(threshold);
    size = size + _i1.U64Codec.codec.sizeHint(nonce);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(0, output);
    const _i1.SequenceCodec<_i3.AccountId32>(_i3.AccountId32Codec()).encodeTo(signers, output);
    _i1.U32Codec.codec.encodeTo(threshold, output);
    _i1.U64Codec.codec.encodeTo(nonce, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateMultisig &&
          _i4.listsEqual(other.signers, signers) &&
          other.threshold == threshold &&
          other.nonce == nonce;

  @override
  int get hashCode => Object.hash(signers, threshold, nonce);
}

/// Propose a transaction to be executed by the multisig
///
/// Parameters:
/// - `multisig_address`: The multisig account that will execute the call
/// - `call`: The encoded call to execute
/// - `expiry`: Block number when this proposal expires
///
/// The proposer must be a signer and must pay:
/// - A deposit (refundable - returned immediately on execution/cancellation)
/// - A fee (non-refundable, burned immediately)
///
/// **For threshold=1:** The proposal is created with `Approved` status immediately
/// and can be executed via `execute()` without additional approvals.
///
/// **Weight:** Charged upfront for worst-case (high-security path with decode).
/// Refunded to actual cost on success based on whether HS path was taken.
class Propose extends Call {
  const Propose({required this.multisigAddress, required this.call, required this.expiry});

  factory Propose._decode(_i1.Input input) {
    return Propose(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      call: _i1.U8SequenceCodec.codec.decode(input),
      expiry: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// Vec<u8>
  final List<int> call;

  /// BlockNumberFor<T>
  final int expiry;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'propose': {'multisigAddress': multisigAddress.toList(), 'call': call, 'expiry': expiry},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U8SequenceCodec.codec.sizeHint(call);
    size = size + _i1.U32Codec.codec.sizeHint(expiry);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(1, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U8SequenceCodec.codec.encodeTo(call, output);
    _i1.U32Codec.codec.encodeTo(expiry, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Propose &&
          _i4.listsEqual(other.multisigAddress, multisigAddress) &&
          _i4.listsEqual(other.call, call) &&
          other.expiry == expiry;

  @override
  int get hashCode => Object.hash(multisigAddress, call, expiry);
}

/// Approve a proposed transaction
///
/// If this approval brings the total approvals to or above the threshold,
/// the proposal status changes to `Approved` and can be executed via `execute()`.
///
/// Parameters:
/// - `multisig_address`: The multisig account
/// - `proposal_id`: ID (nonce) of the proposal to approve
///
/// Weight: Charges for MAX call size, refunds based on actual
class Approve extends Call {
  const Approve({required this.multisigAddress, required this.proposalId});

  factory Approve._decode(_i1.Input input) {
    return Approve(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'approve': {'multisigAddress': multisigAddress.toList(), 'proposalId': proposalId},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(2, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Approve && _i4.listsEqual(other.multisigAddress, multisigAddress) && other.proposalId == proposalId;

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId);
}

/// Cancel a proposed transaction (only by proposer)
///
/// Parameters:
/// - `multisig_address`: The multisig account
/// - `proposal_id`: ID (nonce) of the proposal to cancel
class Cancel extends Call {
  const Cancel({required this.multisigAddress, required this.proposalId});

  factory Cancel._decode(_i1.Input input) {
    return Cancel(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'cancel': {'multisigAddress': multisigAddress.toList(), 'proposalId': proposalId},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(3, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cancel && _i4.listsEqual(other.multisigAddress, multisigAddress) && other.proposalId == proposalId;

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId);
}

/// Remove expired proposals and return deposits to proposers
///
/// Can only be called by signers of the multisig.
/// Removes Active or Approved proposals that have expired (past expiry block).
/// Executed and Cancelled proposals are automatically cleaned up immediately.
///
/// Approved+expired proposals can become stuck if proposer is unavailable (e.g. lost
/// keys, compromise). Allowing any signer to remove them prevents permanent deposit
/// lockup and enables multisig dissolution.
///
/// The deposit is always returned to the original proposer, not the caller.
class RemoveExpired extends Call {
  const RemoveExpired({required this.multisigAddress, required this.proposalId});

  factory RemoveExpired._decode(_i1.Input input) {
    return RemoveExpired(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'remove_expired': {'multisigAddress': multisigAddress.toList(), 'proposalId': proposalId},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(4, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RemoveExpired &&
          _i4.listsEqual(other.multisigAddress, multisigAddress) &&
          other.proposalId == proposalId;

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId);
}

/// Claim all deposits from expired proposals
///
/// This is a batch operation that removes all expired proposals where:
/// - Caller is the proposer
/// - Proposal is Active or Approved and past expiry block
///
/// Note: Executed and Cancelled proposals are automatically cleaned up immediately,
/// so only Active+Expired and Approved+Expired proposals need manual cleanup.
///
/// Returns all proposal deposits to the proposer in a single transaction.
class ClaimDeposits extends Call {
  const ClaimDeposits({required this.multisigAddress});

  factory ClaimDeposits._decode(_i1.Input input) {
    return ClaimDeposits(multisigAddress: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'claim_deposits': {'multisigAddress': multisigAddress.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(5, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ClaimDeposits && _i4.listsEqual(other.multisigAddress, multisigAddress);

  @override
  int get hashCode => multisigAddress.hashCode;
}

/// Execute an approved proposal
///
/// Can be called by any signer of the multisig once the proposal has reached
/// the approval threshold (status = Approved). The proposal must not be expired.
///
/// On execution:
/// - The call is decoded and dispatched as the multisig account
/// - Proposal is removed from storage
/// - Deposit is returned to the proposer
///
/// Parameters:
/// - `multisig_address`: The multisig account
/// - `proposal_id`: ID (nonce) of the proposal to execute
class Execute extends Call {
  const Execute({required this.multisigAddress, required this.proposalId});

  factory Execute._decode(_i1.Input input) {
    return Execute(
      multisigAddress: const _i1.U8ArrayCodec(32).decode(input),
      proposalId: _i1.U32Codec.codec.decode(input),
    );
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  /// u32
  final int proposalId;

  @override
  Map<String, Map<String, dynamic>> toJson() => {
    'execute': {'multisigAddress': multisigAddress.toList(), 'proposalId': proposalId},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    size = size + _i1.U32Codec.codec.sizeHint(proposalId);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(7, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
    _i1.U32Codec.codec.encodeTo(proposalId, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Execute && _i4.listsEqual(other.multisigAddress, multisigAddress) && other.proposalId == proposalId;

  @override
  int get hashCode => Object.hash(multisigAddress, proposalId);
}

/// Approve dissolving a multisig account
///
/// Signers call this to approve dissolving the multisig.
/// When threshold is reached, the multisig is automatically dissolved.
///
/// Requirements:
/// - Caller must be a signer
/// - No proposals exist (active, executed, or cancelled) - must be fully cleaned up
/// - Multisig account balance must be zero
///
/// When threshold is reached:
/// - Deposit is returned to creator
/// - Multisig storage is removed
class ApproveDissolve extends Call {
  const ApproveDissolve({required this.multisigAddress});

  factory ApproveDissolve._decode(_i1.Input input) {
    return ApproveDissolve(multisigAddress: const _i1.U8ArrayCodec(32).decode(input));
  }

  /// T::AccountId
  final _i3.AccountId32 multisigAddress;

  @override
  Map<String, Map<String, List<int>>> toJson() => {
    'approve_dissolve': {'multisigAddress': multisigAddress.toList()},
  };

  int _sizeHint() {
    int size = 1;
    size = size + const _i3.AccountId32Codec().sizeHint(multisigAddress);
    return size;
  }

  void encodeTo(_i1.Output output) {
    _i1.U8Codec.codec.encodeTo(6, output);
    const _i1.U8ArrayCodec(32).encodeTo(multisigAddress, output);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ApproveDissolve && _i4.listsEqual(other.multisigAddress, multisigAddress);

  @override
  int get hashCode => multisigAddress.hashCode;
}
