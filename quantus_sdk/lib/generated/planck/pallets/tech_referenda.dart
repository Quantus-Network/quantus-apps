// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;
import 'dart:typed_data' as _i8;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/frame_support/traits/preimages/bounded.dart' as _i11;
import '../types/frame_support/traits/schedule/dispatch_time.dart' as _i12;
import '../types/pallet_referenda/pallet/call.dart' as _i13;
import '../types/pallet_referenda/types/curve.dart' as _i15;
import '../types/pallet_referenda/types/referendum_info.dart' as _i4;
import '../types/pallet_referenda/types/track_details.dart' as _i14;
import '../types/primitive_types/h256.dart' as _i6;
import '../types/quantus_runtime/origin_caller.dart' as _i10;
import '../types/quantus_runtime/runtime_call.dart' as _i9;
import '../types/sp_core/crypto/account_id32.dart' as _i3;
import '../types/tuples.dart' as _i5;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<int> _referendumCount = const _i1.StorageValue<int>(
    prefix: 'TechReferenda',
    storage: 'ReferendumCount',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageValue<int> _activeReferendaCount = const _i1.StorageValue<int>(
    prefix: 'TechReferenda',
    storage: 'ActiveReferendaCount',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageMap<_i3.AccountId32, int> _activeSubmissionCount = const _i1.StorageMap<_i3.AccountId32, int>(
    prefix: 'TechReferenda',
    storage: 'ActiveSubmissionCount',
    valueCodec: _i2.U32Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i3.AccountId32Codec()),
  );

  final _i1.StorageMap<int, _i4.ReferendumInfo> _referendumInfoFor = const _i1.StorageMap<int, _i4.ReferendumInfo>(
    prefix: 'TechReferenda',
    storage: 'ReferendumInfoFor',
    valueCodec: _i4.ReferendumInfo.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, List<_i5.Tuple2<int, int>>> _trackQueue =
      const _i1.StorageMap<int, List<_i5.Tuple2<int, int>>>(
        prefix: 'TechReferenda',
        storage: 'TrackQueue',
        valueCodec: _i2.SequenceCodec<_i5.Tuple2<int, int>>(
          _i5.Tuple2Codec<int, int>(_i2.U32Codec.codec, _i2.U32Codec.codec),
        ),
        hasher: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
      );

  final _i1.StorageMap<int, int> _decidingCount = const _i1.StorageMap<int, int>(
    prefix: 'TechReferenda',
    storage: 'DecidingCount',
    valueCodec: _i2.U32Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
  );

  final _i1.StorageMap<int, _i6.H256> _metadataOf = const _i1.StorageMap<int, _i6.H256>(
    prefix: 'TechReferenda',
    storage: 'MetadataOf',
    valueCodec: _i6.H256Codec(),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  /// The next free referendum index, aka the number of referenda started so far.
  _i7.Future<int> referendumCount({_i1.BlockHash? at}) async {
    final hashedKey = _referendumCount.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _referendumCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// The number of referenda currently in the `Ongoing` state, across all tracks.
  ///
  /// Incremented on `submit` and decremented whenever a referendum reaches a terminal
  /// state (approved, rejected, timed out, cancelled or killed). Bounds admissions at
  /// [`Config::MaxActive`].
  _i7.Future<int> activeReferendaCount({_i1.BlockHash? at}) async {
    final hashedKey = _activeReferendaCount.hashedKey();
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _activeReferendaCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// The number of referenda currently in the `Ongoing` state per submitter.
  ///
  /// Maintained alongside [`ActiveReferendaCount`] (incremented on `submit`, decremented
  /// on every terminal transition) and bounds each account's admissions at
  /// [`Config::MaxActivePerAccount`], so no single submitter can exhaust the shared
  /// [`Config::MaxActive`] capacity.
  _i7.Future<int> activeSubmissionCount(_i3.AccountId32 key1, {_i1.BlockHash? at}) async {
    final hashedKey = _activeSubmissionCount.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _activeSubmissionCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Information concerning any given referendum.
  _i7.Future<_i4.ReferendumInfo?> referendumInfoFor(int key1, {_i1.BlockHash? at}) async {
    final hashedKey = _referendumInfoFor.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _referendumInfoFor.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The sorted list of referenda ready to be decided but not yet being decided, ordered by
  /// conviction-weighted approvals.
  ///
  /// This should be empty if `DecidingCount` is less than `TrackInfo::max_deciding`.
  _i7.Future<List<_i5.Tuple2<int, int>>> trackQueue(int key1, {_i1.BlockHash? at}) async {
    final hashedKey = _trackQueue.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _trackQueue.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// The number of referenda being decided currently.
  _i7.Future<int> decidingCount(int key1, {_i1.BlockHash? at}) async {
    final hashedKey = _decidingCount.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _decidingCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// The metadata is a general information concerning the referendum.
  /// The `Hash` refers to the preimage of the `Preimages` provider which can be a JSON
  /// dump or IPFS hash of a JSON file.
  ///
  /// Consider a garbage collection for a metadata of finished referendums to `unrequest` (remove)
  /// large preimages.
  _i7.Future<_i6.H256?> metadataOf(int key1, {_i1.BlockHash? at}) async {
    final hashedKey = _metadataOf.hashedKeyFor(key1);
    final bytes = await __api.getStorage(hashedKey, at: at);
    if (bytes != null) {
      return _metadataOf.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The number of referenda currently in the `Ongoing` state per submitter.
  ///
  /// Maintained alongside [`ActiveReferendaCount`] (incremented on `submit`, decremented
  /// on every terminal transition) and bounds each account's admissions at
  /// [`Config::MaxActivePerAccount`], so no single submitter can exhaust the shared
  /// [`Config::MaxActive`] capacity.
  _i7.Future<List<int>> multiActiveSubmissionCount(List<_i3.AccountId32> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _activeSubmissionCount.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _activeSubmissionCount.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => 0).toList() as List<int>); /* Default */
  }

  /// Information concerning any given referendum.
  _i7.Future<List<_i4.ReferendumInfo?>> multiReferendumInfoFor(List<int> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _referendumInfoFor.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _referendumInfoFor.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// The sorted list of referenda ready to be decided but not yet being decided, ordered by
  /// conviction-weighted approvals.
  ///
  /// This should be empty if `DecidingCount` is less than `TrackInfo::max_deciding`.
  _i7.Future<List<List<_i5.Tuple2<int, int>>>> multiTrackQueue(List<int> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _trackQueue.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _trackQueue.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => []).toList() as List<List<_i5.Tuple2<int, int>>>); /* Default */
  }

  /// The number of referenda being decided currently.
  _i7.Future<List<int>> multiDecidingCount(List<int> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _decidingCount.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _decidingCount.decodeValue(v.key)).toList();
    }
    return (keys.map((key) => 0).toList() as List<int>); /* Default */
  }

  /// The metadata is a general information concerning the referendum.
  /// The `Hash` refers to the preimage of the `Preimages` provider which can be a JSON
  /// dump or IPFS hash of a JSON file.
  ///
  /// Consider a garbage collection for a metadata of finished referendums to `unrequest` (remove)
  /// large preimages.
  _i7.Future<List<_i6.H256?>> multiMetadataOf(List<int> keys, {_i1.BlockHash? at}) async {
    final hashedKeys = keys.map((key) => _metadataOf.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(hashedKeys, at: at);
    if (bytes.isNotEmpty) {
      return bytes.first.changes.map((v) => _metadataOf.decodeValue(v.key)).toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `referendumCount`.
  _i8.Uint8List referendumCountKey() {
    final hashedKey = _referendumCount.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `activeReferendaCount`.
  _i8.Uint8List activeReferendaCountKey() {
    final hashedKey = _activeReferendaCount.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `activeSubmissionCount`.
  _i8.Uint8List activeSubmissionCountKey(_i3.AccountId32 key1) {
    final hashedKey = _activeSubmissionCount.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `referendumInfoFor`.
  _i8.Uint8List referendumInfoForKey(int key1) {
    final hashedKey = _referendumInfoFor.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `trackQueue`.
  _i8.Uint8List trackQueueKey(int key1) {
    final hashedKey = _trackQueue.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `decidingCount`.
  _i8.Uint8List decidingCountKey(int key1) {
    final hashedKey = _decidingCount.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `metadataOf`.
  _i8.Uint8List metadataOfKey(int key1) {
    final hashedKey = _metadataOf.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `activeSubmissionCount`.
  _i8.Uint8List activeSubmissionCountMapPrefix() {
    final hashedKey = _activeSubmissionCount.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `referendumInfoFor`.
  _i8.Uint8List referendumInfoForMapPrefix() {
    final hashedKey = _referendumInfoFor.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `trackQueue`.
  _i8.Uint8List trackQueueMapPrefix() {
    final hashedKey = _trackQueue.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `decidingCount`.
  _i8.Uint8List decidingCountMapPrefix() {
    final hashedKey = _decidingCount.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `metadataOf`.
  _i8.Uint8List metadataOfMapPrefix() {
    final hashedKey = _metadataOf.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Propose a referendum on a privileged action.
  ///
  /// - `origin`: must be `SubmitOrigin` and the account must have `SubmissionDeposit` funds
  ///  available.
  /// - `proposal_origin`: The origin from which the proposal should be executed.
  /// - `proposal`: The proposal.
  /// - `enactment_moment`: The moment that the proposal should be enacted.
  ///
  /// Emits `Submitted`.
  _i9.TechReferenda submit({
    required _i10.OriginCaller proposalOrigin,
    required _i11.Bounded proposal,
    required _i12.DispatchTime enactmentMoment,
  }) {
    return _i9.TechReferenda(
      _i13.Submit(proposalOrigin: proposalOrigin, proposal: proposal, enactmentMoment: enactmentMoment),
    );
  }

  /// Post the Decision Deposit for a referendum.
  ///
  /// - `origin`: must be `Signed` and the account must have funds available for the
  ///  referendum's track's Decision Deposit.
  /// - `index`: The index of the submitted referendum whose Decision Deposit is yet to be
  ///  posted.
  ///
  /// Emits `DecisionDepositPlaced`.
  _i9.TechReferenda placeDecisionDeposit({required int index}) {
    return _i9.TechReferenda(_i13.PlaceDecisionDeposit(index: index));
  }

  /// Refund the Decision Deposit for a closed referendum back to the depositor.
  ///
  /// - `origin`: must be `Signed` or `Root`.
  /// - `index`: The index of a closed referendum whose Decision Deposit has not yet been
  ///  refunded.
  ///
  /// Emits `DecisionDepositRefunded`.
  _i9.TechReferenda refundDecisionDeposit({required int index}) {
    return _i9.TechReferenda(_i13.RefundDecisionDeposit(index: index));
  }

  /// Cancel an ongoing referendum.
  ///
  /// - `origin`: must be the `CancelOrigin`.
  /// - `index`: The index of the referendum to be cancelled.
  ///
  /// Emits `Cancelled`.
  _i9.TechReferenda cancel({required int index}) {
    return _i9.TechReferenda(_i13.Cancel(index: index));
  }

  /// Cancel an ongoing referendum and slash the deposits.
  ///
  /// - `origin`: must be the `KillOrigin`.
  /// - `index`: The index of the referendum to be cancelled.
  ///
  /// Emits `Killed` and `DepositSlashed`.
  _i9.TechReferenda kill({required int index}) {
    return _i9.TechReferenda(_i13.Kill(index: index));
  }

  /// Advance a referendum onto its next logical state. Only used internally.
  ///
  /// - `origin`: must be `Root`.
  /// - `index`: the referendum to be advanced.
  _i9.TechReferenda nudgeReferendum({required int index}) {
    return _i9.TechReferenda(_i13.NudgeReferendum(index: index));
  }

  /// Advance a track onto its next logical state. Only used internally.
  ///
  /// - `origin`: must be `Root`.
  /// - `track`: the track to be advanced.
  ///
  /// Action item for when there is now one fewer referendum in the deciding phase and the
  /// `DecidingCount` is not yet updated. This means that we should either:
  /// - begin deciding another referendum (and leave `DecidingCount` alone); or
  /// - decrement `DecidingCount`.
  _i9.TechReferenda oneFewerDeciding({required int track}) {
    return _i9.TechReferenda(_i13.OneFewerDeciding(track: track));
  }

  /// Refund the Submission Deposit for a closed referendum back to the depositor.
  ///
  /// - `origin`: must be `Signed` or `Root`.
  /// - `index`: The index of a closed referendum whose Submission Deposit has not yet been
  ///  refunded.
  ///
  /// Emits `SubmissionDepositRefunded`.
  _i9.TechReferenda refundSubmissionDeposit({required int index}) {
    return _i9.TechReferenda(_i13.RefundSubmissionDeposit(index: index));
  }

  /// Set or clear metadata of a referendum.
  ///
  /// Parameters:
  /// - `origin`: Must be `Signed` by a creator of a referendum or by anyone to clear a
  ///  metadata of a finished referendum.
  /// - `index`:  The index of a referendum to set or clear metadata for.
  /// - `maybe_hash`: The hash of an on-chain stored preimage. `None` to clear a metadata.
  _i9.TechReferenda setMetadata({required int index, _i6.H256? maybeHash}) {
    return _i9.TechReferenda(_i13.SetMetadata(index: index, maybeHash: maybeHash));
  }
}

class Constants {
  Constants();

  /// The minimum amount to be used as a deposit for a public referendum proposal.
  final BigInt submissionDeposit = BigInt.from(100000000000000);

  /// Maximum size of the referendum queue for a single track.
  final int maxQueued = 100;

  /// Maximum number of referenda that may be `Ongoing` at once, across all tracks.
  ///
  /// This is a global admission bound enforced in `submit`. It also covers referenda
  /// that never receive a decision deposit and therefore occupy neither a deciding
  /// slot nor a `TrackQueue` entry, yet hold storage and a scheduler agenda slot
  /// until the `UndecidingTimeout`.
  ///
  /// Must be at least `MaxQueued` plus the sum of all tracks' `max_deciding` plus one,
  /// so that the deciding slots and track queues remain fully utilizable (checked by
  /// `integrity_test`).
  final int maxActive = 128;

  /// The maximum number of referenda any one account may have in the `Ongoing` state
  /// at once.
  ///
  /// [`Config::MaxActive`] is a shared resource: without a per-account cap, any
  /// single account passing `SubmitOrigin` could fill it with refundable-deposit
  /// referenda and freeze submission for everyone — including the very referendum
  /// needed to intervene — until the `UndecidingTimeout` (renewably). Size it so
  /// that no plausible coalition of submitters can reach `MaxActive`:
  /// `MaxActivePerAccount` × (maximum concurrent submitters) < `MaxActive`.
  final int maxActivePerAccount = 8;

  /// Maximum encoded length of a `Lookup` proposal accepted by `submit`.
  ///
  /// `submit` `request`s the preimage so a later `unnote_preimage` cannot delete the
  /// bytes before enactment; that request also lets the noter reclaim their storage
  /// deposit while the bytes stay pinned until the referendum ends. Without a size
  /// bound, `MaxActive` × 4 MiB of deposit-free state can accumulate against only
  /// the refundable [`Config::SubmissionDeposit`]. Size this so that the preimage
  /// deposit for a max-sized blob does not exceed `SubmissionDeposit` — then even
  /// after `unnote` the submission deposit still collateralizes the held bytes.
  final int maxProposalSize = 65536;

  /// The number of blocks after submission that a referendum must begin being decided by.
  /// Once this passes, then anyone may cancel the referendum.
  final int undecidingTimeout = 324000;

  /// Quantization level for the referendum wakeup scheduler. A higher number will result in
  /// fewer storage reads/writes needed for smaller voters, but also result in delays to the
  /// automatic referendum status changes. Explicit servicing instructions are unaffected.
  final int alarmInterval = 1;

  /// A list of tracks.
  ///
  /// Note: if the tracks are dynamic, the value in the static metadata might be inaccurate.
  final List<_i5.Tuple2<int, _i14.TrackDetails>> tracks = [
    _i5.Tuple2<int, _i14.TrackDetails>(
      0,
      _i14.TrackDetails(
        name: 'tech_collective_members',
        maxDeciding: 1,
        decisionDeposit: BigInt.from(1000000000000000),
        preparePeriod: 600,
        decisionPeriod: 7200,
        confirmPeriod: 7200,
        minEnactmentPeriod: 7200,
        minApproval: const _i15.LinearDecreasing(length: 1000000000, floor: 610000000, ceil: 610000000),
        minSupport: const _i15.LinearDecreasing(length: 1000000000, floor: 600000000, ceil: 600000000),
      ),
    ),
  ];
}
