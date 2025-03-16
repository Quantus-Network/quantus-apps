// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i6;
import 'dart:typed_data' as _i7;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i4;

import '../types/frame_support/pallet_id.dart' as _i8;
import '../types/pallet_delegated_staking/types/agent_ledger.dart' as _i5;
import '../types/pallet_delegated_staking/types/delegation.dart' as _i3;
import '../types/sp_arithmetic/per_things/perbill.dart' as _i9;
import '../types/sp_core/crypto/account_id32.dart' as _i2;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageMap<_i2.AccountId32, _i3.Delegation> _delegators =
      const _i1.StorageMap<_i2.AccountId32, _i3.Delegation>(
    prefix: 'DelegatedStaking',
    storage: 'Delegators',
    valueCodec: _i3.Delegation.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageValue<int> _counterForDelegators =
      const _i1.StorageValue<int>(
    prefix: 'DelegatedStaking',
    storage: 'CounterForDelegators',
    valueCodec: _i4.U32Codec.codec,
  );

  final _i1.StorageMap<_i2.AccountId32, _i5.AgentLedger> _agents =
      const _i1.StorageMap<_i2.AccountId32, _i5.AgentLedger>(
    prefix: 'DelegatedStaking',
    storage: 'Agents',
    valueCodec: _i5.AgentLedger.codec,
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.AccountId32Codec()),
  );

  final _i1.StorageValue<int> _counterForAgents = const _i1.StorageValue<int>(
    prefix: 'DelegatedStaking',
    storage: 'CounterForAgents',
    valueCodec: _i4.U32Codec.codec,
  );

  /// Map of Delegators to their `Delegation`.
  ///
  /// Implementation note: We are not using a double map with `delegator` and `agent` account
  /// as keys since we want to restrict delegators to delegate only to one account at a time.
  _i6.Future<_i3.Delegation?> delegators(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _delegators.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _delegators.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Counter for the related counted storage map
  _i6.Future<int> counterForDelegators({_i1.BlockHash? at}) async {
    final hashedKey = _counterForDelegators.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _counterForDelegators.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Map of `Agent` to their `Ledger`.
  _i6.Future<_i5.AgentLedger?> agents(
    _i2.AccountId32 key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _agents.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _agents.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Counter for the related counted storage map
  _i6.Future<int> counterForAgents({_i1.BlockHash? at}) async {
    final hashedKey = _counterForAgents.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _counterForAgents.decodeValue(bytes);
    }
    return 0; /* Default */
  }

  /// Returns the storage key for `delegators`.
  _i7.Uint8List delegatorsKey(_i2.AccountId32 key1) {
    final hashedKey = _delegators.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `counterForDelegators`.
  _i7.Uint8List counterForDelegatorsKey() {
    final hashedKey = _counterForDelegators.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `agents`.
  _i7.Uint8List agentsKey(_i2.AccountId32 key1) {
    final hashedKey = _agents.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `counterForAgents`.
  _i7.Uint8List counterForAgentsKey() {
    final hashedKey = _counterForAgents.hashedKey();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `delegators`.
  _i7.Uint8List delegatorsMapPrefix() {
    final hashedKey = _delegators.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `agents`.
  _i7.Uint8List agentsMapPrefix() {
    final hashedKey = _agents.mapPrefix();
    return hashedKey;
  }
}

class Constants {
  Constants();

  /// Injected identifier for the pallet.
  final _i8.PalletId palletId = const <int>[
    112,
    121,
    47,
    100,
    108,
    115,
    116,
    107,
  ];

  /// Fraction of the slash that is rewarded to the caller of pending slash to the agent.
  final _i9.Perbill slashRewardFraction = 10000000;
}
