// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;
import 'dart:typed_data' as _i7;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i5;

import '../types/frame_support/pallet_id.dart' as _i11;
import '../types/pallet_multisig/multisig_data.dart' as _i3;
import '../types/pallet_multisig/pallet/call.dart' as _i9;
import '../types/pallet_multisig/proposal_data.dart' as _i4;
import '../types/quantus_runtime/runtime_call.dart' as _i8;
import '../types/sp_arithmetic/per_things/permill.dart' as _i10;
import '../types/sp_core/crypto/account_id32.dart' as _i2;
import '../types/sp_weights/weight_v2/weight.dart' as _i12;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.MultisigData> _multisigs =
      const _i1.StorageMap<_i2.AccountId32, _i3.MultisigData>(
        prefix: 'Multisig',
        storage: 'Multisigs',
        valueCodec: _i3.MultisigData.codec,
        hasher: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
      );

  final _i1.StorageDoubleMap<_i2.AccountId32, int, _i4.ProposalData> _proposals =
      const _i1.StorageDoubleMap<_i2.AccountId32, int, _i4.ProposalData>(
        prefix: 'Multisig',
        storage: 'Proposals',
        valueCodec: _i4.ProposalData.codec,
        hasher1: _i1.StorageHasher.blake2b128Concat(_i2.AccountId32Codec()),
        hasher2: _i1.StorageHasher.twoxx64Concat(_i5.U32Codec.codec),
      );

  /// Multisigs stored by their deterministic address
  _i6.Future<_i3.MultisigData?> multisigs(_i2.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _multisigs.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _multisigs.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Proposals indexed by (multisig_address, proposal_nonce)
  _i6.Future<_i4.ProposalData?> proposals(_i2.AccountId32 key1, int key2, {_i1.BlockHash? at}) async {
    final hashedKey = _proposals.hashedKeyFor(key1, key2);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _proposals.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Multisigs stored by their deterministic address
  _i6.Future<List<_i3.MultisigData?>> multiMultisigs(List<_i2.AccountId32> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _multisigs.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _multisigs.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `multisigs`.
  _i7.Uint8List multisigsKey(_i2.AccountId32 key1) {
    final hashedKey = _multisigs.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `proposals`.
  _i7.Uint8List proposalsKey(_i2.AccountId32 key1, int key2) {
    final hashedKey = _proposals.hashedKeyFor(key1, key2);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `multisigs`.
  _i7.Uint8List multisigsMapPrefix() {
    final hashedKey = _multisigs.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `proposals`.
  _i7.Uint8List proposalsMapPrefix(_i2.AccountId32 key1) {
    final hashedKey = _proposals.mapPrefix(key1);
    return hashedKey;
  }
}

class Txs {
  const Txs();

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
  _i8.Multisig createMultisig({required List<_i2.AccountId32> signers, required int threshold, required BigInt nonce}) {
    return _i8.Multisig(_i9.CreateMultisig(signers: signers, threshold: threshold, nonce: nonce));
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
  _i8.Multisig propose({required _i2.AccountId32 multisigAddress, required List<int> call, required int expiry}) {
    return _i8.Multisig(_i9.Propose(multisigAddress: multisigAddress, call: call, expiry: expiry));
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
  _i8.Multisig approve({required _i2.AccountId32 multisigAddress, required int proposalId}) {
    return _i8.Multisig(_i9.Approve(multisigAddress: multisigAddress, proposalId: proposalId));
  }

  /// Cancel a proposed transaction (only by proposer)
  ///
  /// Parameters:
  /// - `multisig_address`: The multisig account
  /// - `proposal_id`: ID (nonce) of the proposal to cancel
  _i8.Multisig cancel({required _i2.AccountId32 multisigAddress, required int proposalId}) {
    return _i8.Multisig(_i9.Cancel(multisigAddress: multisigAddress, proposalId: proposalId));
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
  _i8.Multisig removeExpired({required _i2.AccountId32 multisigAddress, required int proposalId}) {
    return _i8.Multisig(_i9.RemoveExpired(multisigAddress: multisigAddress, proposalId: proposalId));
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
  _i8.Multisig claimDeposits({required _i2.AccountId32 multisigAddress}) {
    return _i8.Multisig(_i9.ClaimDeposits(multisigAddress: multisigAddress));
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
  ///
  /// Note: The weight charged includes both multisig bookkeeping and MaxInnerCallWeight.
  /// Actual weight is refunded based on the inner call's post-dispatch info.
  /// The inner call's weight is validated against MaxInnerCallWeight at propose time.
  _i8.Multisig execute({required _i2.AccountId32 multisigAddress, required int proposalId}) {
    return _i8.Multisig(_i9.Execute(multisigAddress: multisigAddress, proposalId: proposalId));
  }
}

class Constants {
  Constants();

  /// Maximum number of signers allowed in a multisig
  final int maxSigners = 100;

  /// Maximum number of proposals in storage per multisig.
  /// Only Active and Approved proposals are stored; executed and cancelled
  /// proposals are removed immediately. This limit prevents unbounded storage growth.
  final int maxTotalProposalsInStorage = 200;

  /// Maximum size of an encoded call
  final int maxCallSize = 10240;

  /// Fee charged for creating a multisig (non-refundable, burned).
  /// This prevents spam creation of multisig accounts.
  final BigInt multisigFee = BigInt.from(600000000000);

  /// Deposit required per proposal (returned on execute or cancel)
  final BigInt proposalDeposit = BigInt.from(1000000000000);

  /// Fee charged for creating a proposal (non-refundable, paid always)
  final BigInt proposalFee = BigInt.from(1000000000000);

  /// Percentage increase in ProposalFee for each signer in the multisig.
  ///
  /// Formula: `FinalFee = ProposalFee + (ProposalFee * SignerCount * SignerStepFactor)`
  /// Example: If Fee=100, Signers=5, Factor=1%, then Extra = 100 * 5 * 0.01 = 5. Total = 105.
  final _i10.Permill signerStepFactor = 10000;

  /// Pallet ID for generating multisig addresses
  final _i11.PalletId palletId = const <int>[112, 121, 47, 109, 108, 116, 115, 103];

  /// Maximum duration (in blocks) that a proposal can be set to expire in the future.
  /// This prevents proposals from being created with extremely far expiry dates
  /// that would lock deposits and bloat storage for extended periods.
  ///
  /// Example: If set to 100_000 blocks (~2 weeks at 12s blocks),
  /// a proposal created at block 1000 cannot have expiry > 101_000.
  final int maxExpiryDuration = 100800;

  /// Maximum weight allowed for inner calls executed through the multisig.
  ///
  /// This bound ensures that the `execute` extrinsic can safely reserve weight
  /// for the inner call at pre-dispatch time. Proposals with calls exceeding
  /// this weight limit are rejected at propose time.
  ///
  /// The execute extrinsic's weight annotation is: bookkeeping + MaxInnerCallWeight.
  /// This guarantees the block weight is never exceeded by arbitrary inner calls.
  final _i12.Weight maxInnerCallWeight = _i12.Weight(
    refTime: BigInt.from(1000000000000),
    proofSize: BigInt.from(2621440),
  );
}
