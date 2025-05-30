// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i6;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i3;

import '../types/b_tree_map_6.dart' as _i4;
import '../types/polkadot_primitives/v8/validator_index.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<List<List<_i2.ValidatorIndex>>> _validatorGroups =
      const _i1.StorageValue<List<List<_i2.ValidatorIndex>>>(
    prefix: 'ParaScheduler',
    storage: 'ValidatorGroups',
    valueCodec: _i3.SequenceCodec<List<_i2.ValidatorIndex>>(
        _i3.SequenceCodec<_i2.ValidatorIndex>(_i2.ValidatorIndexCodec())),
  );

  final _i1.StorageValue<int> _sessionStartBlock = const _i1.StorageValue<int>(
    prefix: 'ParaScheduler',
    storage: 'SessionStartBlock',
    valueCodec: _i3.U32Codec.codec,
  );

  final _i1.StorageValue<_i4.BTreeMap> _claimQueue =
      const _i1.StorageValue<_i4.BTreeMap>(
    prefix: 'ParaScheduler',
    storage: 'ClaimQueue',
    valueCodec: _i4.BTreeMapCodec(),
  );

  /// All the validator groups. One for each core. Indices are into `ActiveValidators` - not the
  /// broader set of Polkadot validators, but instead just the subset used for parachains during
  /// this session.
  ///
  /// Bound: The number of cores is the sum of the numbers of parachains and parathread
  /// multiplexers. Reasonably, 100-1000. The dominant factor is the number of validators: safe
  /// upper bound at 10k.
  _i5.Future<List<List<_i2.ValidatorIndex>>> validatorGroups(
      {_i1.BlockHash? at}) async {
    final hashedKey = _validatorGroups.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _validatorGroups.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// The block number where the session start occurred. Used to track how many group rotations
  /// have occurred.
  ///
  /// Note that in the context of parachains modules the session change is signaled during
  /// the block and enacted at the end of the block (at the finalization stage, to be exact).
  /// Thus for all intents and purposes the effect of the session change is observed at the
  /// block following the session change, block number of which we save in this storage value.
  _i5.Future<int> sessionStartBlock({_i1.BlockHash? at}) async {
    final hashedKey = _sessionStartBlock.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _sessionStartBlock.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// One entry for each availability core. The `VecDeque` represents the assignments to be
  /// scheduled on that core.
  _i5.Future<_i4.BTreeMap> claimQueue({_i1.BlockHash? at}) async {
    final hashedKey = _claimQueue.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _claimQueue.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Returns the storage key for `validatorGroups`.
  _i6.Uint8List validatorGroupsKey() {
    final hashedKey = _validatorGroups.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `sessionStartBlock`.
  _i6.Uint8List sessionStartBlockKey() {
    final hashedKey = _sessionStartBlock.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `claimQueue`.
  _i6.Uint8List claimQueueKey() {
    final hashedKey = _claimQueue.hashedKey();
    return hashedKey;
  }
}
