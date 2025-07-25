// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i7;
import 'dart:typed_data' as _i8;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i2;

import '../types/pallet_scheduler/pallet/call.dart' as _i10;
import '../types/pallet_scheduler/retry_config.dart' as _i6;
import '../types/pallet_scheduler/scheduled.dart' as _i4;
import '../types/qp_scheduler/block_number_or_timestamp.dart' as _i3;
import '../types/quantus_runtime/runtime_call.dart' as _i9;
import '../types/sp_weights/weight_v2/weight.dart' as _i11;
import '../types/tuples_1.dart' as _i5;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<int> _incompleteBlockSince =
      const _i1.StorageValue<int>(
    prefix: 'Scheduler',
    storage: 'IncompleteBlockSince',
    valueCodec: _i2.U32Codec.codec,
  );

  final _i1.StorageValue<BigInt> _incompleteTimestampSince =
      const _i1.StorageValue<BigInt>(
    prefix: 'Scheduler',
    storage: 'IncompleteTimestampSince',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageValue<BigInt> _lastProcessedTimestamp =
      const _i1.StorageValue<BigInt>(
    prefix: 'Scheduler',
    storage: 'LastProcessedTimestamp',
    valueCodec: _i2.U64Codec.codec,
  );

  final _i1.StorageMap<_i3.BlockNumberOrTimestamp, List<_i4.Scheduled?>>
      _agenda =
      const _i1.StorageMap<_i3.BlockNumberOrTimestamp, List<_i4.Scheduled?>>(
    prefix: 'Scheduler',
    storage: 'Agenda',
    valueCodec: _i2.SequenceCodec<_i4.Scheduled?>(
        _i2.OptionCodec<_i4.Scheduled>(_i4.Scheduled.codec)),
    hasher: _i1.StorageHasher.twoxx64Concat(_i3.BlockNumberOrTimestamp.codec),
  );

  final _i1
      .StorageMap<_i5.Tuple2<_i3.BlockNumberOrTimestamp, int>, _i6.RetryConfig>
      _retries = const _i1.StorageMap<
          _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>, _i6.RetryConfig>(
    prefix: 'Scheduler',
    storage: 'Retries',
    valueCodec: _i6.RetryConfig.codec,
    hasher: _i1.StorageHasher.blake2b128Concat(
        _i5.Tuple2Codec<_i3.BlockNumberOrTimestamp, int>(
      _i3.BlockNumberOrTimestamp.codec,
      _i2.U32Codec.codec,
    )),
  );

  final _i1.StorageMap<List<int>, _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>>
      _lookup = const _i1
          .StorageMap<List<int>, _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>>(
    prefix: 'Scheduler',
    storage: 'Lookup',
    valueCodec: _i5.Tuple2Codec<_i3.BlockNumberOrTimestamp, int>(
      _i3.BlockNumberOrTimestamp.codec,
      _i2.U32Codec.codec,
    ),
    hasher: _i1.StorageHasher.twoxx64Concat(_i2.U8ArrayCodec(32)),
  );

  /// Tracks incomplete block-based agendas that need to be processed in a later block.
  _i7.Future<int?> incompleteBlockSince({_i1.BlockHash? at}) async {
    final hashedKey = _incompleteBlockSince.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _incompleteBlockSince.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Tracks incomplete timestamp-based agendas that need to be processed in a later block.
  _i7.Future<BigInt?> incompleteTimestampSince({_i1.BlockHash? at}) async {
    final hashedKey = _incompleteTimestampSince.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _incompleteTimestampSince.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Tracks the last timestamp bucket that was fully processed.
  /// Used to avoid reprocessing all buckets from 0 on every run.
  _i7.Future<BigInt?> lastProcessedTimestamp({_i1.BlockHash? at}) async {
    final hashedKey = _lastProcessedTimestamp.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _lastProcessedTimestamp.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Items to be executed, indexed by the block number that they should be executed on.
  _i7.Future<List<_i4.Scheduled?>> agenda(
    _i3.BlockNumberOrTimestamp key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _agenda.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _agenda.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// Retry configurations for items to be executed, indexed by task address.
  _i7.Future<_i6.RetryConfig?> retries(
    _i5.Tuple2<_i3.BlockNumberOrTimestamp, int> key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _retries.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _retries.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Lookup from a name to the block number and index of the task.
  ///
  /// For v3 -> v4 the previously unbounded identities are Blake2-256 hashed to form the v4
  /// identities.
  _i7.Future<_i5.Tuple2<_i3.BlockNumberOrTimestamp, int>?> lookup(
    List<int> key1, {
    _i1.BlockHash? at,
  }) async {
    final hashedKey = _lookup.hashedKeyFor(key1);
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _lookup.decodeValue(bytes);
    }
    return null; /* Nullable */
  }

  /// Items to be executed, indexed by the block number that they should be executed on.
  _i7.Future<List<List<_i4.Scheduled?>>> multiAgenda(
    List<_i3.BlockNumberOrTimestamp> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _agenda.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _agenda.decodeValue(v.key))
          .toList();
    }
    return (keys.map((key) => []).toList()
        as List<List<_i4.Scheduled?>>); /* Default */
  }

  /// Retry configurations for items to be executed, indexed by task address.
  _i7.Future<List<_i6.RetryConfig?>> multiRetries(
    List<_i5.Tuple2<_i3.BlockNumberOrTimestamp, int>> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _retries.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _retries.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Lookup from a name to the block number and index of the task.
  ///
  /// For v3 -> v4 the previously unbounded identities are Blake2-256 hashed to form the v4
  /// identities.
  _i7.Future<List<_i5.Tuple2<_i3.BlockNumberOrTimestamp, int>?>> multiLookup(
    List<List<int>> keys, {
    _i1.BlockHash? at,
  }) async {
    final hashedKeys = keys.map((key) => _lookup.hashedKeyFor(key)).toList();
    final bytes = await __api.queryStorageAt(
      hashedKeys,
      at: at,
    );
    if (bytes.isNotEmpty) {
      return bytes.first.changes
          .map((v) => _lookup.decodeValue(v.key))
          .toList();
    }
    return []; /* Nullable */
  }

  /// Returns the storage key for `incompleteBlockSince`.
  _i8.Uint8List incompleteBlockSinceKey() {
    final hashedKey = _incompleteBlockSince.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `incompleteTimestampSince`.
  _i8.Uint8List incompleteTimestampSinceKey() {
    final hashedKey = _incompleteTimestampSince.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `lastProcessedTimestamp`.
  _i8.Uint8List lastProcessedTimestampKey() {
    final hashedKey = _lastProcessedTimestamp.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `agenda`.
  _i8.Uint8List agendaKey(_i3.BlockNumberOrTimestamp key1) {
    final hashedKey = _agenda.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `retries`.
  _i8.Uint8List retriesKey(_i5.Tuple2<_i3.BlockNumberOrTimestamp, int> key1) {
    final hashedKey = _retries.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage key for `lookup`.
  _i8.Uint8List lookupKey(List<int> key1) {
    final hashedKey = _lookup.hashedKeyFor(key1);
    return hashedKey;
  }

  /// Returns the storage map key prefix for `agenda`.
  _i8.Uint8List agendaMapPrefix() {
    final hashedKey = _agenda.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `retries`.
  _i8.Uint8List retriesMapPrefix() {
    final hashedKey = _retries.mapPrefix();
    return hashedKey;
  }

  /// Returns the storage map key prefix for `lookup`.
  _i8.Uint8List lookupMapPrefix() {
    final hashedKey = _lookup.mapPrefix();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Anonymously schedule a task.
  _i9.Scheduler schedule({
    required int when,
    _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>? maybePeriodic,
    required int priority,
    required _i9.RuntimeCall call,
  }) {
    return _i9.Scheduler(_i10.Schedule(
      when: when,
      maybePeriodic: maybePeriodic,
      priority: priority,
      call: call,
    ));
  }

  /// Cancel an anonymously scheduled task.
  _i9.Scheduler cancel({
    required _i3.BlockNumberOrTimestamp when,
    required int index,
  }) {
    return _i9.Scheduler(_i10.Cancel(
      when: when,
      index: index,
    ));
  }

  /// Schedule a named task.
  _i9.Scheduler scheduleNamed({
    required List<int> id,
    required int when,
    _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>? maybePeriodic,
    required int priority,
    required _i9.RuntimeCall call,
  }) {
    return _i9.Scheduler(_i10.ScheduleNamed(
      id: id,
      when: when,
      maybePeriodic: maybePeriodic,
      priority: priority,
      call: call,
    ));
  }

  /// Cancel a named scheduled task.
  _i9.Scheduler cancelNamed({required List<int> id}) {
    return _i9.Scheduler(_i10.CancelNamed(id: id));
  }

  /// Anonymously schedule a task after a delay.
  _i9.Scheduler scheduleAfter({
    required _i3.BlockNumberOrTimestamp after,
    _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>? maybePeriodic,
    required int priority,
    required _i9.RuntimeCall call,
  }) {
    return _i9.Scheduler(_i10.ScheduleAfter(
      after: after,
      maybePeriodic: maybePeriodic,
      priority: priority,
      call: call,
    ));
  }

  /// Schedule a named task after a delay.
  _i9.Scheduler scheduleNamedAfter({
    required List<int> id,
    required _i3.BlockNumberOrTimestamp after,
    _i5.Tuple2<_i3.BlockNumberOrTimestamp, int>? maybePeriodic,
    required int priority,
    required _i9.RuntimeCall call,
  }) {
    return _i9.Scheduler(_i10.ScheduleNamedAfter(
      id: id,
      after: after,
      maybePeriodic: maybePeriodic,
      priority: priority,
      call: call,
    ));
  }

  /// Set a retry configuration for a task so that, in case its scheduled run fails, it will
  /// be retried after `period` blocks, for a total amount of `retries` retries or until it
  /// succeeds.
  ///
  /// Tasks which need to be scheduled for a retry are still subject to weight metering and
  /// agenda space, same as a regular task. If a periodic task fails, it will be scheduled
  /// normally while the task is retrying.
  ///
  /// Tasks scheduled as a result of a retry for a periodic task are unnamed, non-periodic
  /// clones of the original task. Their retry configuration will be derived from the
  /// original task's configuration, but will have a lower value for `remaining` than the
  /// original `total_retries`.
  _i9.Scheduler setRetry({
    required _i5.Tuple2<_i3.BlockNumberOrTimestamp, int> task,
    required int retries,
    required _i3.BlockNumberOrTimestamp period,
  }) {
    return _i9.Scheduler(_i10.SetRetry(
      task: task,
      retries: retries,
      period: period,
    ));
  }

  /// Set a retry configuration for a named task so that, in case its scheduled run fails, it
  /// will be retried after `period` blocks, for a total amount of `retries` retries or until
  /// it succeeds.
  ///
  /// Tasks which need to be scheduled for a retry are still subject to weight metering and
  /// agenda space, same as a regular task. If a periodic task fails, it will be scheduled
  /// normally while the task is retrying.
  ///
  /// Tasks scheduled as a result of a retry for a periodic task are unnamed, non-periodic
  /// clones of the original task. Their retry configuration will be derived from the
  /// original task's configuration, but will have a lower value for `remaining` than the
  /// original `total_retries`.
  _i9.Scheduler setRetryNamed({
    required List<int> id,
    required int retries,
    required _i3.BlockNumberOrTimestamp period,
  }) {
    return _i9.Scheduler(_i10.SetRetryNamed(
      id: id,
      retries: retries,
      period: period,
    ));
  }

  /// Removes the retry configuration of a task.
  _i9.Scheduler cancelRetry(
      {required _i5.Tuple2<_i3.BlockNumberOrTimestamp, int> task}) {
    return _i9.Scheduler(_i10.CancelRetry(task: task));
  }

  /// Cancel the retry configuration of a named task.
  _i9.Scheduler cancelRetryNamed({required List<int> id}) {
    return _i9.Scheduler(_i10.CancelRetryNamed(id: id));
  }
}

class Constants {
  Constants();

  /// The maximum weight that may be scheduled per block for any dispatchables.
  final _i11.Weight maximumWeight = _i11.Weight(
    refTime: BigInt.from(4800000000000),
    proofSize: BigInt.parse(
      '14757395258967641292',
      radix: 10,
    ),
  );

  /// The maximum number of scheduled calls in the queue for a single block.
  ///
  /// NOTE:
  /// + Dependent pallets' benchmarks might require a higher limit for the setting. Set a
  /// higher limit under `runtime-benchmarks` feature.
  final int maxScheduledPerBlock = 50;

  /// Precision of the timestamp buckets.
  ///
  /// Timestamp based dispatches are rounded to the nearest bucket of this precision.
  final BigInt timestampBucketSize = BigInt.from(40000);
}
