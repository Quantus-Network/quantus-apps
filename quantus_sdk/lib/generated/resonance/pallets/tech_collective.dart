// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;
import 'dart:typed_data' as _i7;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/pallet_ranked_collective/member_record.dart' as _i4;
import '../types/pallet_ranked_collective/pallet/call.dart' as _i10;
import '../types/pallet_ranked_collective/vote_record.dart' as _i5;
import '../types/resonance_runtime/runtime_call.dart' as _i8;
import '../types/sp_core/crypto/account_id32.dart' as _i3;
import '../types/sp_runtime/multiaddress/multi_address.dart' as _i9;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<int, int> _memberCount = const _i1.StorageMap<int, int>(
    prefix: 'TechCollective',
    storage: 'MemberCount',
    valueCodec: _i2.U32Codec.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
  );

  final _i1.StorageMap<_i3.AccountId32, _i4.MemberRecord> _members =
      const _i1.StorageMap<_i3.AccountId32, _i4.MemberRecord>(
    prefix: 'TechCollective',
    storage: 'Members',
    valueCodec: _i4.MemberRecord.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i3.AccountId32Codec()),
  );

  final _i1.StorageDoubleMap<int, _i3.AccountId32, int> _idToIndex =
      const _i1.StorageDoubleMap<int, _i3.AccountId32, int>(
    prefix: 'TechCollective',
    storage: 'IdToIndex',
    valueCodec: _i2.U32Codec.codec,
    hasher1: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
    hasher2: _i1.StorageHasher.twoxx64Concat(_i3.AccountId32Codec()),
  );

  final _i1.StorageDoubleMap<int, int, _i3.AccountId32> _indexToId =
      const _i1.StorageDoubleMap<int, int, _i3.AccountId32>(
    prefix: 'TechCollective',
    storage: 'IndexToId',
    valueCodec: _i3.AccountId32Codec(),
    hasher1: _i1.StorageHasher.twoxx64Concat(_i2.U16Codec.codec),
    hasher2: _i1.StorageHasher.twoxx64Concat(_i2.U32Codec.codec),
  );

  final _i1.StorageDoubleMap<int, _i3.AccountId32, _i5.VoteRecord> _voting =
      const _i1.StorageDoubleMap<int, _i3.AccountId32, _i5.VoteRecord>(
    prefix: 'TechCollective',
    storage: 'Voting',
    valueCodec: _i5.VoteRecord.codec,
    hasher1: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
    hasher2: _i1.StorageHasher.twoxx64Concat(_i3.AccountId32Codec()),
  );

  final _i1.StorageMap<int, List<int>> _votingCleanup =
      const _i1.StorageMap<int, List<int>>(
    prefix: 'TechCollective',
    storage: 'VotingCleanup',
    valueCodec: _i2.U8SequenceCodec.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(_i2.U32Codec.codec),
  );

  /// The number of members in the collective who have at least the rank according to the index
  /// of the vec.
  _i6.Future<int> memberCount(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _memberCount.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _memberCount.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// The current members of the collective.
  _i6.Future<_i4.MemberRecord?> members(
    _i3.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _members.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _members.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The index of each ranks's member into the group of members who have at least that rank.
  _i6.Future<int?> idToIndex(
    int key1,
    _i3.AccountId32 key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _idToIndex.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _idToIndex.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// The members in the collective by index. All indices in the range `0..MemberCount` will
  /// return `Some`, however a member's index is not guaranteed to remain unchanged over time.
  _i6.Future<_i3.AccountId32?> indexToId(
    int key1,
    int key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _indexToId.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _indexToId.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Votes on a given proposal, if it is ongoing.
  _i6.Future<_i5.VoteRecord?> voting(
    int key1,
    _i3.AccountId32 key2, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _voting.hashedKeyFor(
      key1,
      key2,
    );
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _voting.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  _i6.Future<List<int>?> votingCleanup(
    int key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _votingCleanup.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _votingCleanup.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Returns the storage key for `memberCount`.
  _i7.Uint8List memberCountKey(int key1) {
    final hashedKey = _memberCount.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `members`.
  _i7.Uint8List membersKey(_i3.AccountId32 key1) {
    final hashedKey = _members.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `idToIndex`.
  _i7.Uint8List idToIndexKey(
    int key1,
    _i3.AccountId32 key2,
  ) {
    final hashedKey = _idToIndex.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `indexToId`.
  _i7.Uint8List indexToIdKey(
    int key1,
    int key2,
  ) {
    final hashedKey = _indexToId.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `voting`.
  _i7.Uint8List votingKey(
    int key1,
    _i3.AccountId32 key2,
  ) {
    final hashedKey = _voting.hashedKeyFor(
      key1,
      key2,
    );
    return hashedKey;
  }

  /// Returns the storage key for `votingCleanup`.
  _i7.Uint8List votingCleanupKey(int key1) {
    final hashedKey = _votingCleanup.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `memberCount`.
  _i7.Uint8List memberCountMapPrefix() {
    final hashedKey = _memberCount.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `members`.
  _i7.Uint8List membersMapPrefix() {
    final hashedKey = _members.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `idToIndex`.
  _i7.Uint8List idToIndexMapPrefix(int key1) {
    final hashedKey = _idToIndex.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `indexToId`.
  _i7.Uint8List indexToIdMapPrefix(int key1) {
    final hashedKey = _indexToId.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `voting`.
  _i7.Uint8List votingMapPrefix(int key1) {
    final hashedKey = _voting.mapPrefix(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `votingCleanup`.
  _i7.Uint8List votingCleanupMapPrefix() {
    final hashedKey = _votingCleanup.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Introduce a new member.
  ///
  /// - `origin`: Must be the `AddOrigin`.
  /// - `who`: Account of non-member which will become a member.
  ///
  /// Weight: `O(1)`
  _i8.TechCollective addMember({required _i9.MultiAddress who}) {
    return _i8.TechCollective(_i10.AddMember(who: who));
  }

  /// Increment the rank of an existing member by one.
  ///
  /// - `origin`: Must be the `PromoteOrigin`.
  /// - `who`: Account of existing member.
  ///
  /// Weight: `O(1)`
  _i8.TechCollective promoteMember({required _i9.MultiAddress who}) {
    return _i8.TechCollective(_i10.PromoteMember(who: who));
  }

  /// Decrement the rank of an existing member by one. If the member is already at rank zero,
  /// then they are removed entirely.
  ///
  /// - `origin`: Must be the `DemoteOrigin`.
  /// - `who`: Account of existing member of rank greater than zero.
  ///
  /// Weight: `O(1)`, less if the member's index is highest in its rank.
  _i8.TechCollective demoteMember({required _i9.MultiAddress who}) {
    return _i8.TechCollective(_i10.DemoteMember(who: who));
  }

  /// Remove the member entirely.
  ///
  /// - `origin`: Must be the `RemoveOrigin`.
  /// - `who`: Account of existing member of rank greater than zero.
  /// - `min_rank`: The rank of the member or greater.
  ///
  /// Weight: `O(min_rank)`.
  _i8.TechCollective removeMember({
    required _i9.MultiAddress who,
    required int minRank,
  }) {
    return _i8.TechCollective(_i10.RemoveMember(
      who: who,
      minRank: minRank,
    ));
  }

  /// Add an aye or nay vote for the sender to the given proposal.
  ///
  /// - `origin`: Must be `Signed` by a member account.
  /// - `poll`: Index of a poll which is ongoing.
  /// - `aye`: `true` if the vote is to approve the proposal, `false` otherwise.
  ///
  /// Transaction fees are be waived if the member is voting on any particular proposal
  /// for the first time and the call is successful. Subsequent vote changes will charge a
  /// fee.
  ///
  /// Weight: `O(1)`, less if there was no previous vote on the poll by the member.
  _i8.TechCollective vote({
    required int poll,
    required bool aye,
  }) {
    return _i8.TechCollective(_i10.Vote(
      poll: poll,
      aye: aye,
    ));
  }

  /// Remove votes from the given poll. It must have ended.
  ///
  /// - `origin`: Must be `Signed` by any account.
  /// - `poll_index`: Index of a poll which is completed and for which votes continue to
  ///  exist.
  /// - `max`: Maximum number of vote items from remove in this call.
  ///
  /// Transaction fees are waived if the operation is successful.
  ///
  /// Weight `O(max)` (less if there are fewer items to remove than `max`).
  _i8.TechCollective cleanupPoll({
    required int pollIndex,
    required int max,
  }) {
    return _i8.TechCollective(_i10.CleanupPoll(
      pollIndex: pollIndex,
      max: max,
    ));
  }

  /// Exchanges a member with a new account and the same existing rank.
  ///
  /// - `origin`: Must be the `ExchangeOrigin`.
  /// - `who`: Account of existing member of rank greater than zero to be exchanged.
  /// - `new_who`: New Account of existing member of rank greater than zero to exchanged to.
  _i8.TechCollective exchangeMember({
    required _i9.MultiAddress who,
    required _i9.MultiAddress newWho,
  }) {
    return _i8.TechCollective(_i10.ExchangeMember(
      who: who,
      newWho: newWho,
    ));
  }
}
