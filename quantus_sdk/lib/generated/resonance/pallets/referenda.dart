// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;
import 'dart:typed_data' as _i7;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/frame_support/traits/preimages/bounded.dart' as _i10;
import '../types/frame_support/traits/schedule/dispatch_time.dart' as _i11;
import '../types/pallet_referenda/pallet/call_1.dart' as _i12;
import '../types/pallet_referenda/types/curve.dart' as _i14;
import '../types/pallet_referenda/types/referendum_info_1.dart' as _i3;
import '../types/pallet_referenda/types/track_info.dart' as _i13;
import '../types/primitive_types/h256.dart' as _i5;
import '../types/quantus_runtime/origin_caller.dart' as _i9;
import '../types/quantus_runtime/runtime_call.dart' as _i8;
import '../types/tuples.dart' as _i4;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<int> _referendumCount = const _i1.StorageValue<int>(
    prefix: 'Referenda',
    storage: 'ReferendumCount',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageMap<int, _i3.ReferendumInfo> _referendumInfoFor =
      const _i1.StorageMap<int, _i3.ReferendumInfo>(
    prefix: 'Referenda',
    storage: 'ReferendumInfoFor',
    valueCodec: _i3.ReferendumInfo.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, List<_i4.Tuple2<int, BigInt>>> _trackQueue =
      const _i1.StorageMap<int, List<_i4.Tuple2<int, BigInt>>>(
    prefix: 'Referenda',
    storage: 'TrackQueue',
    valueCodec:
        _i2.SequenceCodec<_i4.Tuple2<int, BigInt>>(_i4.Tuple2Codec<int, BigInt>(
      _i2.U32Codec.codec,
      _i2.U128Codec.codec,
    )),
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
  );

  final _i1.StorageMap<int, int> _decidingCount =
      const _i1.StorageMap<int, int>(
    prefix: 'Referenda',
    storage: 'DecidingCount',
    valueCodec: _i2.U32Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
  );

  final _i1.StorageMap<int, _i5.H256> _metadataOf =
      const _i1.StorageMap<int, _i5.H256>(
    prefix: 'Referenda',
    storage: 'MetadataOf',
    valueCodec: _i5.H256Codec(),
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  /// The next free referendum index, aka the number of referenda started so far.
  _i6.Future<int> referendumCount({_i1.BlockHash? at}) async {
    final hashedKey = _referendumCount.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _referendumCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Information concerning any given referendum.
  _i6.Future<_i3.ReferendumInfo?> referendumInfoFor(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _referendumInfoFor.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _referendumInfoFor.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The sorted list of referenda ready to be decided but not yet being decided, ordered by
  /// conviction-weighted approvals.
  ///
  /// This should be empty if `DecidingCount` is less than `TrackInfo::max_deciding`.
  _i6.Future<List<_i4.Tuple2<int, BigInt>>> trackQueue(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _trackQueue.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _trackQueue.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// The number of referenda being decided currently.
  _i6.Future<int> decidingCount(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _decidingCount.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
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
  _i6.Future<_i5.H256?> metadataOf(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _metadataOf.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _metadataOf.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Information concerning any given referendum.
  _i6.Future<List<_i3.ReferendumInfo?>> multiReferendumInfoFor(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _referendumInfoFor.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _referendumInfoFor.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// The sorted list of referenda ready to be decided but not yet being decided, ordered by
  /// conviction-weighted approvals.
  ///
  /// This should be empty if `DecidingCount` is less than `TrackInfo::max_deciding`.
  _i6.Future<List<List<_i4.Tuple2<int, BigInt>>>> multiTrackQueue(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _trackQueue.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _trackQueue.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => []).toList()
        as List<List<_i4.Tuple2<int, BigInt>>>); /* Default */
  }

  /// The number of referenda being decided currently.
  _i6.Future<List<int>> multiDecidingCount(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _decidingCount.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _decidingCount.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => 0).toList() as List<int>); /* Default */
  }

  /// The metadata is a general information concerning the referendum.
  /// The `Hash` refers to the preimage of the `Preimages` provider which can be a JSON
  /// dump or IPFS hash of a JSON file.
  ///
  /// Consider a garbage collection for a metadata of finished referendums to `unrequest` (remove)
  /// large preimages.
  _i6.Future<List<_i5.H256?>> multiMetadataOf(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _metadataOf.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _metadataOf.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `referendumCount`.
  _i7.Uint8List referendumCountKey() {
    final hashedKey = _referendumCount.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `referendumInfoFor`.
  _i7.Uint8List referendumInfoForKey(int key1) {
    final hashedKey = _referendumInfoFor.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `trackQueue`.
  _i7.Uint8List trackQueueKey(int key1) {
    final hashedKey = _trackQueue.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `decidingCount`.
  _i7.Uint8List decidingCountKey(int key1) {
    final hashedKey = _decidingCount.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `metadataOf`.
  _i7.Uint8List metadataOfKey(int key1) {
    final hashedKey = _metadataOf.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `referendumInfoFor`.
  _i7.Uint8List referendumInfoForMapPrefix() {
    final hashedKey = _referendumInfoFor.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `trackQueue`.
  _i7.Uint8List trackQueueMapPrefix() {
    final hashedKey = _trackQueue.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `decidingCount`.
  _i7.Uint8List decidingCountMapPrefix() {
    final hashedKey = _decidingCount.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `metadataOf`.
  _i7.Uint8List metadataOfMapPrefix() {
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
  _i8.Referenda submit({
    required _i9.OriginCaller proposalOrigin,
    required _i10.Bounded proposal,
    required _i11.DispatchTime enactmentMoment,
  }) {
    return _i8.Referenda(_i12.Submit(
      proposalOrigin: proposalOrigin,
      proposal: proposal,
      enactmentMoment: enactmentMoment,
    ));
  }

  /// Post the Decision Deposit for a referendum.
  ///
  /// - `origin`: must be `Signed` and the account must have funds available for the
  ///  referendum's track's Decision Deposit.
  /// - `index`: The index of the submitted referendum whose Decision Deposit is yet to be
  ///  posted.
  ///
  /// Emits `DecisionDepositPlaced`.
  _i8.Referenda placeDecisionDeposit({required int index}) {
    return _i8.Referenda(_i12.PlaceDecisionDeposit(index: index));
  }

  /// Refund the Decision Deposit for a closed referendum back to the depositor.
  ///
  /// - `origin`: must be `Signed` or `Root`.
  /// - `index`: The index of a closed referendum whose Decision Deposit has not yet been
  ///  refunded.
  ///
  /// Emits `DecisionDepositRefunded`.
  _i8.Referenda refundDecisionDeposit({required int index}) {
    return _i8.Referenda(_i12.RefundDecisionDeposit(index: index));
  }

  /// Cancel an ongoing referendum.
  ///
  /// - `origin`: must be the `CancelOrigin`.
  /// - `index`: The index of the referendum to be cancelled.
  ///
  /// Emits `Cancelled`.
  _i8.Referenda cancel({required int index}) {
    return _i8.Referenda(_i12.Cancel(index: index));
  }

  /// Cancel an ongoing referendum and slash the deposits.
  ///
  /// - `origin`: must be the `KillOrigin`.
  /// - `index`: The index of the referendum to be cancelled.
  ///
  /// Emits `Killed` and `DepositSlashed`.
  _i8.Referenda kill({required int index}) {
    return _i8.Referenda(_i12.Kill(index: index));
  }

  /// Advance a referendum onto its next logical state. Only used internally.
  ///
  /// - `origin`: must be `Root`.
  /// - `index`: the referendum to be advanced.
  _i8.Referenda nudgeReferendum({required int index}) {
    return _i8.Referenda(_i12.NudgeReferendum(index: index));
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
  _i8.Referenda oneFewerDeciding({required int track}) {
    return _i8.Referenda(_i12.OneFewerDeciding(track: track));
  }

  /// Refund the Submission Deposit for a closed referendum back to the depositor.
  ///
  /// - `origin`: must be `Signed` or `Root`.
  /// - `index`: The index of a closed referendum whose Submission Deposit has not yet been
  ///  refunded.
  ///
  /// Emits `SubmissionDepositRefunded`.
  _i8.Referenda refundSubmissionDeposit({required int index}) {
    return _i8.Referenda(_i12.RefundSubmissionDeposit(index: index));
  }

  /// Set or clear metadata of a referendum.
  ///
  /// Parameters:
  /// - `origin`: Must be `Signed` by a creator of a referendum or by anyone to clear a
  ///  metadata of a finished referendum.
  /// - `index`:  The index of a referendum to set or clear metadata for.
  /// - `maybe_hash`: The hash of an on-chain stored preimage. `None` to clear a metadata.
  _i8.Referenda setMetadata({
    required int index,
    _i5.H256? maybeHash,
  }) {
    return _i8.Referenda(_i12.SetMetadata(
      index: index,
      maybeHash: maybeHash,
    ));
  }
}

class Constants {
  Constants();

  /// The minimum amount to be used as a deposit for a public referendum proposal.
  final BigInt submissionDeposit = BigInt.from(100000000000000);

  /// Maximum size of the referendum queue for a single track.
  final int maxQueued = 100;

  /// The number of blocks after submission that a referendum must begin being decided by.
  /// Once this passes, then anyone may cancel the referendum.
  final int undecidingTimeout = 3888000;

  /// Quantization level for the referendum wakeup scheduler. A higher number will result in
  /// fewer storage reads/writes needed for smaller voters, but also result in delays to the
  /// automatic referendum status changes. Explicit servicing instructions are unaffected.
  final int alarmInterval = 1;

  /// Information concerning the different referendum tracks.
  final List<_i4.Tuple2<int, _i13.TrackInfo>> tracks = [
    _i4.Tuple2<int, _i13.TrackInfo>(
      0,
      _i13.TrackInfo(
        name: 'signed',
        maxDeciding: 5,
        decisionDeposit: BigInt.from(500000000000000),
        preparePeriod: 43200,
        decisionPeriod: 604800,
        confirmPeriod: 43200,
        minEnactmentPeriod: 86400,
        minApproval: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 550000000,
          ceil: 700000000,
        ),
        minSupport: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 50000000,
          ceil: 250000000,
        ),
      ),
    ),
    _i4.Tuple2<int, _i13.TrackInfo>(
      1,
      _i13.TrackInfo(
        name: 'signaling',
        maxDeciding: 20,
        decisionDeposit: BigInt.from(100000000000000),
        preparePeriod: 21600,
        decisionPeriod: 432000,
        confirmPeriod: 10800,
        minEnactmentPeriod: 1,
        minApproval: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 500000000,
          ceil: 600000000,
        ),
        minSupport: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 10000000,
          ceil: 100000000,
        ),
      ),
    ),
    _i4.Tuple2<int, _i13.TrackInfo>(
      2,
      _i13.TrackInfo(
        name: 'treasury_small_spender',
        maxDeciding: 5,
        decisionDeposit: BigInt.from(100000000000000),
        preparePeriod: 86400,
        decisionPeriod: 259200,
        confirmPeriod: 86400,
        minEnactmentPeriod: 43200,
        minApproval: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 250000000,
          ceil: 500000000,
        ),
        minSupport: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 10000000,
          ceil: 100000000,
        ),
      ),
    ),
    _i4.Tuple2<int, _i13.TrackInfo>(
      3,
      _i13.TrackInfo(
        name: 'treasury_medium_spender',
        maxDeciding: 2,
        decisionDeposit: BigInt.from(250000000000000),
        preparePeriod: 21600,
        decisionPeriod: 432000,
        confirmPeriod: 86400,
        minEnactmentPeriod: 43200,
        minApproval: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 500000000,
          ceil: 750000000,
        ),
        minSupport: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 20000000,
          ceil: 100000000,
        ),
      ),
    ),
    _i4.Tuple2<int, _i13.TrackInfo>(
      4,
      _i13.TrackInfo(
        name: 'treasury_big_spender',
        maxDeciding: 2,
        decisionDeposit: BigInt.from(500000000000000),
        preparePeriod: 86400,
        decisionPeriod: 604800,
        confirmPeriod: 172800,
        minEnactmentPeriod: 43200,
        minApproval: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 650000000,
          ceil: 850000000,
        ),
        minSupport: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 50000000,
          ceil: 150000000,
        ),
      ),
    ),
    _i4.Tuple2<int, _i13.TrackInfo>(
      5,
      _i13.TrackInfo(
        name: 'treasury_treasurer',
        maxDeciding: 1,
        decisionDeposit: BigInt.from(1000000000000000),
        preparePeriod: 172800,
        decisionPeriod: 1209600,
        confirmPeriod: 345600,
        minEnactmentPeriod: 86400,
        minApproval: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 750000000,
          ceil: 1000000000,
        ),
        minSupport: const _i14.LinearDecreasing(
          length: 1000000000,
          floor: 100000000,
          ceil: 250000000,
        ),
      ),
    ),
  ];
}
