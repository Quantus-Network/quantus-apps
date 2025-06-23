// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/pallet_child_bounties/child_bounty.dart' as _i3;
import '../types/pallet_child_bounties/pallet/call.dart' as _i8;
import '../types/polkadot_runtime/runtime_call.dart' as _i7;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i9;
import '../types/tuples_1.dart' as _i4;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<int> _childBountyCount = const _i1.StorageValue<int>(
    prefix: 'ChildBounties',
    storage: 'ChildBountyCount',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageMap<int, int> _parentChildBounties =
      const _i1.StorageMap<int, int>(
    prefix: 'ChildBounties',
    storage: 'ParentChildBounties',
    valueCodec: _i2.U32Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, int> _parentTotalChildBounties =
      const _i1.StorageMap<int, int>(
    prefix: 'ChildBounties',
    storage: 'ParentTotalChildBounties',
    valueCodec: _i2.U32Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageDoubleMap<int, int, _i3.ChildBounty> _childBounties =
      const _i1.StorageDoubleMap<int, int, _i3.ChildBounty>(
    prefix: 'ChildBounties',
    storage: 'ChildBounties',
    valueCodec: _i3.ChildBounty.codec,
    hasher1: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
    hasher2: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageDoubleMap<int, int, List<int>> _childBountyDescriptionsV1 =
      const _i1.StorageDoubleMap<int, int, List<int>>(
    prefix: 'ChildBounties',
    storage: 'ChildBountyDescriptionsV1',
    valueCodec: _i2.U8SequenceCodec.codec,
    hasher1: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
    hasher2: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, _i4.Tuple2<int, int>> _v0ToV1ChildBountyIds =
      const _i1.StorageMap<int, _i4.Tuple2<int, int>>(
    prefix: 'ChildBounties',
    storage: 'V0ToV1ChildBountyIds',
    valueCodec: _i4.Tuple2Codec<int, int>(
      _i2.U32Codec.codec,
      _i2.U32Codec.codec,
    ),
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageMap<int, BigInt> _childrenCuratorFees =
      const _i1.StorageMap<int, BigInt>(
    prefix: 'ChildBounties',
    storage: 'ChildrenCuratorFees',
    valueCodec: _i2.U128Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  /// DEPRECATED: Replaced with `ParentTotalChildBounties` storage item keeping dedicated counts
  /// for each parent bounty. Number of total child bounties. Will be removed in May 2025.
  _i5.Future<int> childBountyCount({_i1.BlockHash? at}) async {
    final hashedKey = _childBountyCount.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _childBountyCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Number of active child bounties per parent bounty.
  /// Map of parent bounty index to number of child bounties.
  _i5.Future<int> parentChildBounties(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _parentChildBounties.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _parentChildBounties.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Number of total child bounties per parent bounty, including completed bounties.
  _i5.Future<int> parentTotalChildBounties(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _parentTotalChildBounties.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _parentTotalChildBounties.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Child bounties that have been added.
  _i5.Future<_i3.ChildBounty?> childBounties(
    int key1,
    int key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _childBounties.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _childBounties.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The description of each child-bounty. Indexed by `(parent_id, child_id)`.
  ///
  /// This item replaces the `ChildBountyDescriptions` storage item from the V0 storage version.
  _i5.Future<List<int>?> childBountyDescriptionsV1(
    int key1,
    int key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _childBountyDescriptionsV1.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _childBountyDescriptionsV1.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The mapping of the child bounty ids from storage version `V0` to the new `V1` version.
  ///
  /// The `V0` ids based on total child bounty count [`ChildBountyCount`]`. The `V1` version ids
  /// based on the child bounty count per parent bounty [`ParentTotalChildBounties`].
  /// The item intended solely for client convenience and not used in the pallet's core logic.
  _i5.Future<_i4.Tuple2<int, int>?> v0ToV1ChildBountyIds(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _v0ToV1ChildBountyIds.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _v0ToV1ChildBountyIds.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The cumulative child-bounty curator fee for each parent bounty.
  _i5.Future<BigInt> childrenCuratorFees(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _childrenCuratorFees.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _childrenCuratorFees.decodeValue(bytes);
    }
    return BigInt.zero; /* Default */
  }

  /// Number of active child bounties per parent bounty.
  /// Map of parent bounty index to number of child bounties.
  _i5.Future<List<int>> multiParentChildBounties(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _parentChildBounties.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _parentChildBounties.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => 0).toList() as List<int>); /* Default */
  }

  /// Number of total child bounties per parent bounty, including completed bounties.
  _i5.Future<List<int>> multiParentTotalChildBounties(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _parentTotalChildBounties.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _parentTotalChildBounties.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => 0).toList() as List<int>); /* Default */
  }

  /// The mapping of the child bounty ids from storage version `V0` to the new `V1` version.
  ///
  /// The `V0` ids based on total child bounty count [`ChildBountyCount`]`. The `V1` version ids
  /// based on the child bounty count per parent bounty [`ParentTotalChildBounties`].
  /// The item intended solely for client convenience and not used in the pallet's core logic.
  _i5.Future<List<_i4.Tuple2<int, int>?>> multiV0ToV1ChildBountyIds(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _v0ToV1ChildBountyIds.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _v0ToV1ChildBountyIds.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// The cumulative child-bounty curator fee for each parent bounty.
  _i5.Future<List<BigInt>> multiChildrenCuratorFees(
    List<int> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys =
        keys.map((key) => _childrenCuratorFees.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _childrenCuratorFees.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => BigInt.zero).toList()
        as List<BigInt>); /* Default */
  }

  /// Returns the storage key for `childBountyCount`.
  _i6.Uint8List childBountyCountKey() {
    final hashedKey = _childBountyCount.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `parentChildBounties`.
  _i6.Uint8List parentChildBountiesKey(int key1) {
    final hashedKey = _parentChildBounties.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `parentTotalChildBounties`.
  _i6.Uint8List parentTotalChildBountiesKey(int key1) {
    final hashedKey = _parentTotalChildBounties.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `childBounties`.
  _i6.Uint8List childBountiesKey(
    int key1,
    int key2,
  ) {
    final hashedKey = _childBounties.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `childBountyDescriptionsV1`.
  _i6.Uint8List childBountyDescriptionsV1Key(
    int key1,
    int key2,
  ) {
    final hashedKey = _childBountyDescriptionsV1.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `v0ToV1ChildBountyIds`.
  _i6.Uint8List v0ToV1ChildBountyIdsKey(int key1) {
    final hashedKey = _v0ToV1ChildBountyIds.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `childrenCuratorFees`.
  _i6.Uint8List childrenCuratorFeesKey(int key1) {
    final hashedKey = _childrenCuratorFees.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `parentChildBounties`.
  _i6.Uint8List parentChildBountiesMapPrefix() {
    final hashedKey = _parentChildBounties.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `parentTotalChildBounties`.
  _i6.Uint8List parentTotalChildBountiesMapPrefix() {
    final hashedKey = _parentTotalChildBounties.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `childBounties`.
  _i6.Uint8List childBountiesMapPrefix(int key1) {
    final hashedKey = _childBounties.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `childBountyDescriptionsV1`.
  _i6.Uint8List childBountyDescriptionsV1MapPrefix(int key1) {
    final hashedKey = _childBountyDescriptionsV1.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `v0ToV1ChildBountyIds`.
  _i6.Uint8List v0ToV1ChildBountyIdsMapPrefix() {
    final hashedKey = _v0ToV1ChildBountyIds.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `childrenCuratorFees`.
  _i6.Uint8List childrenCuratorFeesMapPrefix() {
    final hashedKey = _childrenCuratorFees.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Add a new child-bounty.
  ///
  /// The dispatch origin for this call must be the curator of parent
  /// bounty and the parent bounty must be in "active" state.
  ///
  /// Child-bounty gets added successfully & fund gets transferred from
  /// parent bounty to child-bounty account, if parent bounty has enough
  /// funds, else the call fails.
  ///
  /// Upper bound to maximum number of active  child bounties that can be
  /// added are managed via runtime trait config
  /// [`Config::MaxActiveChildBountyCount`].
  ///
  /// If the call is success, the status of child-bounty is updated to
  /// "Added".
  ///
  /// - `parent_bounty_id`: Index of parent bounty for which child-bounty is being added.
  /// - `value`: Value for executing the proposal.
  /// - `description`: Text description for the child-bounty.
  _i7.ChildBounties addChildBounty({
    required BigInt parentBountyId,
    required BigInt value,
    required List<int> description,
  }) {
    return _i7.ChildBounties(_i8.AddChildBounty(
      parentBountyId: parentBountyId,
      value: value,
      description: description,
    ));
  }

  /// Propose curator for funded child-bounty.
  ///
  /// The dispatch origin for this call must be curator of parent bounty.
  ///
  /// Parent bounty must be in active state, for this child-bounty call to
  /// work.
  ///
  /// Child-bounty must be in "Added" state, for processing the call. And
  /// state of child-bounty is moved to "CuratorProposed" on successful
  /// call completion.
  ///
  /// - `parent_bounty_id`: Index of parent bounty.
  /// - `child_bounty_id`: Index of child bounty.
  /// - `curator`: Address of child-bounty curator.
  /// - `fee`: payment fee to child-bounty curator for execution.
  _i7.ChildBounties proposeCurator({
    required BigInt parentBountyId,
    required BigInt childBountyId,
    required _i9.MultiAddress curator,
    required BigInt fee,
  }) {
    return _i7.ChildBounties(_i8.ProposeCurator(
      parentBountyId: parentBountyId,
      childBountyId: childBountyId,
      curator: curator,
      fee: fee,
    ));
  }

  /// Accept the curator role for the child-bounty.
  ///
  /// The dispatch origin for this call must be the curator of this
  /// child-bounty.
  ///
  /// A deposit will be reserved from the curator and refund upon
  /// successful payout or cancellation.
  ///
  /// Fee for curator is deducted from curator fee of parent bounty.
  ///
  /// Parent bounty must be in active state, for this child-bounty call to
  /// work.
  ///
  /// Child-bounty must be in "CuratorProposed" state, for processing the
  /// call. And state of child-bounty is moved to "Active" on successful
  /// call completion.
  ///
  /// - `parent_bounty_id`: Index of parent bounty.
  /// - `child_bounty_id`: Index of child bounty.
  _i7.ChildBounties acceptCurator({
    required BigInt parentBountyId,
    required BigInt childBountyId,
  }) {
    return _i7.ChildBounties(_i8.AcceptCurator(
      parentBountyId: parentBountyId,
      childBountyId: childBountyId,
    ));
  }

  /// Unassign curator from a child-bounty.
  ///
  /// The dispatch origin for this call can be either `RejectOrigin`, or
  /// the curator of the parent bounty, or any signed origin.
  ///
  /// For the origin other than T::RejectOrigin and the child-bounty
  /// curator, parent bounty must be in active state, for this call to
  /// work. We allow child-bounty curator and T::RejectOrigin to execute
  /// this call irrespective of the parent bounty state.
  ///
  /// If this function is called by the `RejectOrigin` or the
  /// parent bounty curator, we assume that the child-bounty curator is
  /// malicious or inactive. As a result, child-bounty curator deposit is
  /// slashed.
  ///
  /// If the origin is the child-bounty curator, we take this as a sign
  /// that they are unable to do their job, and are willingly giving up.
  /// We could slash the deposit, but for now we allow them to unreserve
  /// their deposit and exit without issue. (We may want to change this if
  /// it is abused.)
  ///
  /// Finally, the origin can be anyone iff the child-bounty curator is
  /// "inactive". Expiry update due of parent bounty is used to estimate
  /// inactive state of child-bounty curator.
  ///
  /// This allows anyone in the community to call out that a child-bounty
  /// curator is not doing their due diligence, and we should pick a new
  /// one. In this case the child-bounty curator deposit is slashed.
  ///
  /// State of child-bounty is moved to Added state on successful call
  /// completion.
  ///
  /// - `parent_bounty_id`: Index of parent bounty.
  /// - `child_bounty_id`: Index of child bounty.
  _i7.ChildBounties unassignCurator({
    required BigInt parentBountyId,
    required BigInt childBountyId,
  }) {
    return _i7.ChildBounties(_i8.UnassignCurator(
      parentBountyId: parentBountyId,
      childBountyId: childBountyId,
    ));
  }

  /// Award child-bounty to a beneficiary.
  ///
  /// The beneficiary will be able to claim the funds after a delay.
  ///
  /// The dispatch origin for this call must be the parent curator or
  /// curator of this child-bounty.
  ///
  /// Parent bounty must be in active state, for this child-bounty call to
  /// work.
  ///
  /// Child-bounty must be in active state, for processing the call. And
  /// state of child-bounty is moved to "PendingPayout" on successful call
  /// completion.
  ///
  /// - `parent_bounty_id`: Index of parent bounty.
  /// - `child_bounty_id`: Index of child bounty.
  /// - `beneficiary`: Beneficiary account.
  _i7.ChildBounties awardChildBounty({
    required BigInt parentBountyId,
    required BigInt childBountyId,
    required _i9.MultiAddress beneficiary,
  }) {
    return _i7.ChildBounties(_i8.AwardChildBounty(
      parentBountyId: parentBountyId,
      childBountyId: childBountyId,
      beneficiary: beneficiary,
    ));
  }

  /// Claim the payout from an awarded child-bounty after payout delay.
  ///
  /// The dispatch origin for this call may be any signed origin.
  ///
  /// Call works independent of parent bounty state, No need for parent
  /// bounty to be in active state.
  ///
  /// The Beneficiary is paid out with agreed bounty value. Curator fee is
  /// paid & curator deposit is unreserved.
  ///
  /// Child-bounty must be in "PendingPayout" state, for processing the
  /// call. And instance of child-bounty is removed from the state on
  /// successful call completion.
  ///
  /// - `parent_bounty_id`: Index of parent bounty.
  /// - `child_bounty_id`: Index of child bounty.
  _i7.ChildBounties claimChildBounty({
    required BigInt parentBountyId,
    required BigInt childBountyId,
  }) {
    return _i7.ChildBounties(_i8.ClaimChildBounty(
      parentBountyId: parentBountyId,
      childBountyId: childBountyId,
    ));
  }

  /// Cancel a proposed or active child-bounty. Child-bounty account funds
  /// are transferred to parent bounty account. The child-bounty curator
  /// deposit may be unreserved if possible.
  ///
  /// The dispatch origin for this call must be either parent curator or
  /// `T::RejectOrigin`.
  ///
  /// If the state of child-bounty is `Active`, curator deposit is
  /// unreserved.
  ///
  /// If the state of child-bounty is `PendingPayout`, call fails &
  /// returns `PendingPayout` error.
  ///
  /// For the origin other than T::RejectOrigin, parent bounty must be in
  /// active state, for this child-bounty call to work. For origin
  /// T::RejectOrigin execution is forced.
  ///
  /// Instance of child-bounty is removed from the state on successful
  /// call completion.
  ///
  /// - `parent_bounty_id`: Index of parent bounty.
  /// - `child_bounty_id`: Index of child bounty.
  _i7.ChildBounties closeChildBounty({
    required BigInt parentBountyId,
    required BigInt childBountyId,
  }) {
    return _i7.ChildBounties(_i8.CloseChildBounty(
      parentBountyId: parentBountyId,
      childBountyId: childBountyId,
    ));
  }
}

class Constants {
  Constants();

  /// Maximum number of child bounties that can be added to a parent bounty.
  final int maxActiveChildBountyCount = 100;

  /// Minimum value for a child-bounty.
  final BigInt childBountyValueMinimum = BigInt.from(10000000000);
}
