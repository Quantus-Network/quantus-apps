// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i5;
import 'dart:typed_data' as _i7;

import 'package:polkadart/polkadart.dart' as _i1;
import 'package:polkadart/scale_codec.dart' as _i4;

import '../types/polkadot_primitives/v8/approval_voting_params.dart' as _i8;
import '../types/polkadot_primitives/v8/async_backing/async_backing_params.dart'
    as _i6;
import '../types/polkadot_primitives/v8/executor_params/executor_params.dart'
    as _i12;
import '../types/polkadot_primitives/v8/scheduler_params.dart' as _i9;
import '../types/polkadot_runtime/runtime_call.dart' as _i10;
import '../types/polkadot_runtime_parachains/configuration/host_configuration.dart'
    as _i2;
import '../types/polkadot_runtime_parachains/configuration/pallet/call.dart'
    as _i11;
import '../types/sp_arithmetic/per_things/perbill.dart' as _i13;
import '../types/tuples.dart' as _i3;

class Queries {
  const Queries(this.__api);

  final _i1.StateApi __api;

  final _i1.StorageValue<_i2.HostConfiguration> _activeConfig =
      const _i1.StorageValue<_i2.HostConfiguration>(
    prefix: 'Configuration',
    storage: 'ActiveConfig',
    valueCodec: _i2.HostConfiguration.codec,
  );

  final _i1.StorageValue<List<_i3.Tuple2<int, _i2.HostConfiguration>>>
      _pendingConfigs =
      const _i1.StorageValue<List<_i3.Tuple2<int, _i2.HostConfiguration>>>(
    prefix: 'Configuration',
    storage: 'PendingConfigs',
    valueCodec: _i4.SequenceCodec<_i3.Tuple2<int, _i2.HostConfiguration>>(
        _i3.Tuple2Codec<int, _i2.HostConfiguration>(
      _i4.U32Codec.codec,
      _i2.HostConfiguration.codec,
    )),
  );

  final _i1.StorageValue<bool> _bypassConsistencyCheck =
      const _i1.StorageValue<bool>(
    prefix: 'Configuration',
    storage: 'BypassConsistencyCheck',
    valueCodec: _i4.BoolCodec.codec,
  );

  /// The active configuration for the current session.
  _i5.Future<_i2.HostConfiguration> activeConfig({_i1.BlockHash? at}) async {
    final hashedKey = _activeConfig.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _activeConfig.decodeValue(bytes);
    }
    return _i2.HostConfiguration(
      maxCodeSize: 3145728,
      maxHeadDataSize: 0,
      maxUpwardQueueCount: 0,
      maxUpwardQueueSize: 0,
      maxUpwardMessageSize: 0,
      maxUpwardMessageNumPerCandidate: 0,
      hrmpMaxMessageNumPerCandidate: 0,
      validationUpgradeCooldown: 0,
      validationUpgradeDelay: 2,
      asyncBackingParams: _i6.AsyncBackingParams(
        maxCandidateDepth: 0,
        allowedAncestryLen: 0,
      ),
      maxPovSize: 0,
      maxDownwardMessageSize: 0,
      hrmpMaxParachainOutboundChannels: 0,
      hrmpSenderDeposit: BigInt.zero,
      hrmpRecipientDeposit: BigInt.zero,
      hrmpChannelMaxCapacity: 0,
      hrmpChannelMaxTotalSize: 0,
      hrmpMaxParachainInboundChannels: 0,
      hrmpChannelMaxMessageSize: 0,
      executorParams: [],
      codeRetentionPeriod: 0,
      maxValidators: null,
      disputePeriod: 6,
      disputePostConclusionAcceptancePeriod: 100,
      noShowSlots: 1,
      nDelayTranches: 1,
      zerothDelayTrancheWidth: 0,
      neededApprovals: 0,
      relayVrfModuloSamples: 0,
      pvfVotingTtl: 2,
      minimumValidationUpgradeDelay: 2,
      minimumBackingVotes: 2,
      nodeFeatures: _i4.BitArray.fromByteBuffer(
        0,
        _i7.Uint32List.fromList(const []).buffer,
      ),
      approvalVotingParams:
          _i8.ApprovalVotingParams(maxApprovalCoalesceCount: 1),
      schedulerParams: _i9.SchedulerParams(
        groupRotationFrequency: 1,
        parasAvailabilityPeriod: 1,
        maxValidatorsPerCore: null,
        lookahead: 1,
        numCores: 0,
        maxAvailabilityTimeouts: 0,
        onDemandQueueMaxSize: 10000,
        onDemandTargetQueueUtilization: 250000000,
        onDemandFeeVariability: 30000000,
        onDemandBaseFee: BigInt.from(10000000),
        ttl: 5,
      ),
    ); /* Default */
  }

  /// Pending configuration changes.
  ///
  /// This is a list of configuration changes, each with a session index at which it should
  /// be applied.
  ///
  /// The list is sorted ascending by session index. Also, this list can only contain at most
  /// 2 items: for the next session and for the `scheduled_session`.
  _i5.Future<List<_i3.Tuple2<int, _i2.HostConfiguration>>> pendingConfigs(
      {_i1.BlockHash? at}) async {
    final hashedKey = _pendingConfigs.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _pendingConfigs.decodeValue(bytes);
    }
    return []; /* Default */
  }

  /// If this is set, then the configuration setters will bypass the consistency checks. This
  /// is meant to be used only as the last resort.
  _i5.Future<bool> bypassConsistencyCheck({_i1.BlockHash? at}) async {
    final hashedKey = _bypassConsistencyCheck.hashedKey();
    final bytes = await __api.getStorage(
      hashedKey,
      at: at,
    );
    if (bytes != null) {
      return _bypassConsistencyCheck.decodeValue(bytes);
    }
    return false; /* Default */
  }

  /// Returns the storage key for `activeConfig`.
  _i7.Uint8List activeConfigKey() {
    final hashedKey = _activeConfig.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `pendingConfigs`.
  _i7.Uint8List pendingConfigsKey() {
    final hashedKey = _pendingConfigs.hashedKey();
    return hashedKey;
  }

  /// Returns the storage key for `bypassConsistencyCheck`.
  _i7.Uint8List bypassConsistencyCheckKey() {
    final hashedKey = _bypassConsistencyCheck.hashedKey();
    return hashedKey;
  }
}

class Txs {
  const Txs();

  /// Set the validation upgrade cooldown.
  _i10.Configuration setValidationUpgradeCooldown({required int new_}) {
    return _i10.Configuration(_i11.SetValidationUpgradeCooldown(new_: new_));
  }

  /// Set the validation upgrade delay.
  _i10.Configuration setValidationUpgradeDelay({required int new_}) {
    return _i10.Configuration(_i11.SetValidationUpgradeDelay(new_: new_));
  }

  /// Set the acceptance period for an included candidate.
  _i10.Configuration setCodeRetentionPeriod({required int new_}) {
    return _i10.Configuration(_i11.SetCodeRetentionPeriod(new_: new_));
  }

  /// Set the max validation code size for incoming upgrades.
  _i10.Configuration setMaxCodeSize({required int new_}) {
    return _i10.Configuration(_i11.SetMaxCodeSize(new_: new_));
  }

  /// Set the max POV block size for incoming upgrades.
  _i10.Configuration setMaxPovSize({required int new_}) {
    return _i10.Configuration(_i11.SetMaxPovSize(new_: new_));
  }

  /// Set the max head data size for paras.
  _i10.Configuration setMaxHeadDataSize({required int new_}) {
    return _i10.Configuration(_i11.SetMaxHeadDataSize(new_: new_));
  }

  /// Set the number of coretime execution cores.
  ///
  /// NOTE: that this configuration is managed by the coretime chain. Only manually change
  /// this, if you really know what you are doing!
  _i10.Configuration setCoretimeCores({required int new_}) {
    return _i10.Configuration(_i11.SetCoretimeCores(new_: new_));
  }

  /// Set the max number of times a claim may timeout on a core before it is abandoned
  _i10.Configuration setMaxAvailabilityTimeouts({required int new_}) {
    return _i10.Configuration(_i11.SetMaxAvailabilityTimeouts(new_: new_));
  }

  /// Set the parachain validator-group rotation frequency
  _i10.Configuration setGroupRotationFrequency({required int new_}) {
    return _i10.Configuration(_i11.SetGroupRotationFrequency(new_: new_));
  }

  /// Set the availability period for paras.
  _i10.Configuration setParasAvailabilityPeriod({required int new_}) {
    return _i10.Configuration(_i11.SetParasAvailabilityPeriod(new_: new_));
  }

  /// Set the scheduling lookahead, in expected number of blocks at peak throughput.
  _i10.Configuration setSchedulingLookahead({required int new_}) {
    return _i10.Configuration(_i11.SetSchedulingLookahead(new_: new_));
  }

  /// Set the maximum number of validators to assign to any core.
  _i10.Configuration setMaxValidatorsPerCore({int? new_}) {
    return _i10.Configuration(_i11.SetMaxValidatorsPerCore(new_: new_));
  }

  /// Set the maximum number of validators to use in parachain consensus.
  _i10.Configuration setMaxValidators({int? new_}) {
    return _i10.Configuration(_i11.SetMaxValidators(new_: new_));
  }

  /// Set the dispute period, in number of sessions to keep for disputes.
  _i10.Configuration setDisputePeriod({required int new_}) {
    return _i10.Configuration(_i11.SetDisputePeriod(new_: new_));
  }

  /// Set the dispute post conclusion acceptance period.
  _i10.Configuration setDisputePostConclusionAcceptancePeriod(
      {required int new_}) {
    return _i10.Configuration(
        _i11.SetDisputePostConclusionAcceptancePeriod(new_: new_));
  }

  /// Set the no show slots, in number of number of consensus slots.
  /// Must be at least 1.
  _i10.Configuration setNoShowSlots({required int new_}) {
    return _i10.Configuration(_i11.SetNoShowSlots(new_: new_));
  }

  /// Set the total number of delay tranches.
  _i10.Configuration setNDelayTranches({required int new_}) {
    return _i10.Configuration(_i11.SetNDelayTranches(new_: new_));
  }

  /// Set the zeroth delay tranche width.
  _i10.Configuration setZerothDelayTrancheWidth({required int new_}) {
    return _i10.Configuration(_i11.SetZerothDelayTrancheWidth(new_: new_));
  }

  /// Set the number of validators needed to approve a block.
  _i10.Configuration setNeededApprovals({required int new_}) {
    return _i10.Configuration(_i11.SetNeededApprovals(new_: new_));
  }

  /// Set the number of samples to do of the `RelayVRFModulo` approval assignment criterion.
  _i10.Configuration setRelayVrfModuloSamples({required int new_}) {
    return _i10.Configuration(_i11.SetRelayVrfModuloSamples(new_: new_));
  }

  /// Sets the maximum items that can present in a upward dispatch queue at once.
  _i10.Configuration setMaxUpwardQueueCount({required int new_}) {
    return _i10.Configuration(_i11.SetMaxUpwardQueueCount(new_: new_));
  }

  /// Sets the maximum total size of items that can present in a upward dispatch queue at
  /// once.
  _i10.Configuration setMaxUpwardQueueSize({required int new_}) {
    return _i10.Configuration(_i11.SetMaxUpwardQueueSize(new_: new_));
  }

  /// Set the critical downward message size.
  _i10.Configuration setMaxDownwardMessageSize({required int new_}) {
    return _i10.Configuration(_i11.SetMaxDownwardMessageSize(new_: new_));
  }

  /// Sets the maximum size of an upward message that can be sent by a candidate.
  _i10.Configuration setMaxUpwardMessageSize({required int new_}) {
    return _i10.Configuration(_i11.SetMaxUpwardMessageSize(new_: new_));
  }

  /// Sets the maximum number of messages that a candidate can contain.
  _i10.Configuration setMaxUpwardMessageNumPerCandidate({required int new_}) {
    return _i10.Configuration(
        _i11.SetMaxUpwardMessageNumPerCandidate(new_: new_));
  }

  /// Sets the number of sessions after which an HRMP open channel request expires.
  _i10.Configuration setHrmpOpenRequestTtl({required int new_}) {
    return _i10.Configuration(_i11.SetHrmpOpenRequestTtl(new_: new_));
  }

  /// Sets the amount of funds that the sender should provide for opening an HRMP channel.
  _i10.Configuration setHrmpSenderDeposit({required BigInt new_}) {
    return _i10.Configuration(_i11.SetHrmpSenderDeposit(new_: new_));
  }

  /// Sets the amount of funds that the recipient should provide for accepting opening an HRMP
  /// channel.
  _i10.Configuration setHrmpRecipientDeposit({required BigInt new_}) {
    return _i10.Configuration(_i11.SetHrmpRecipientDeposit(new_: new_));
  }

  /// Sets the maximum number of messages allowed in an HRMP channel at once.
  _i10.Configuration setHrmpChannelMaxCapacity({required int new_}) {
    return _i10.Configuration(_i11.SetHrmpChannelMaxCapacity(new_: new_));
  }

  /// Sets the maximum total size of messages in bytes allowed in an HRMP channel at once.
  _i10.Configuration setHrmpChannelMaxTotalSize({required int new_}) {
    return _i10.Configuration(_i11.SetHrmpChannelMaxTotalSize(new_: new_));
  }

  /// Sets the maximum number of inbound HRMP channels a parachain is allowed to accept.
  _i10.Configuration setHrmpMaxParachainInboundChannels({required int new_}) {
    return _i10.Configuration(
        _i11.SetHrmpMaxParachainInboundChannels(new_: new_));
  }

  /// Sets the maximum size of a message that could ever be put into an HRMP channel.
  _i10.Configuration setHrmpChannelMaxMessageSize({required int new_}) {
    return _i10.Configuration(_i11.SetHrmpChannelMaxMessageSize(new_: new_));
  }

  /// Sets the maximum number of outbound HRMP channels a parachain is allowed to open.
  _i10.Configuration setHrmpMaxParachainOutboundChannels({required int new_}) {
    return _i10.Configuration(
        _i11.SetHrmpMaxParachainOutboundChannels(new_: new_));
  }

  /// Sets the maximum number of outbound HRMP messages can be sent by a candidate.
  _i10.Configuration setHrmpMaxMessageNumPerCandidate({required int new_}) {
    return _i10.Configuration(
        _i11.SetHrmpMaxMessageNumPerCandidate(new_: new_));
  }

  /// Set the number of session changes after which a PVF pre-checking voting is rejected.
  _i10.Configuration setPvfVotingTtl({required int new_}) {
    return _i10.Configuration(_i11.SetPvfVotingTtl(new_: new_));
  }

  /// Sets the minimum delay between announcing the upgrade block for a parachain until the
  /// upgrade taking place.
  ///
  /// See the field documentation for information and constraints for the new value.
  _i10.Configuration setMinimumValidationUpgradeDelay({required int new_}) {
    return _i10.Configuration(
        _i11.SetMinimumValidationUpgradeDelay(new_: new_));
  }

  /// Setting this to true will disable consistency checks for the configuration setters.
  /// Use with caution.
  _i10.Configuration setBypassConsistencyCheck({required bool new_}) {
    return _i10.Configuration(_i11.SetBypassConsistencyCheck(new_: new_));
  }

  /// Set the asynchronous backing parameters.
  _i10.Configuration setAsyncBackingParams(
      {required _i6.AsyncBackingParams new_}) {
    return _i10.Configuration(_i11.SetAsyncBackingParams(new_: new_));
  }

  /// Set PVF executor parameters.
  _i10.Configuration setExecutorParams({required _i12.ExecutorParams new_}) {
    return _i10.Configuration(_i11.SetExecutorParams(new_: new_));
  }

  /// Set the on demand (parathreads) base fee.
  _i10.Configuration setOnDemandBaseFee({required BigInt new_}) {
    return _i10.Configuration(_i11.SetOnDemandBaseFee(new_: new_));
  }

  /// Set the on demand (parathreads) fee variability.
  _i10.Configuration setOnDemandFeeVariability({required _i13.Perbill new_}) {
    return _i10.Configuration(_i11.SetOnDemandFeeVariability(new_: new_));
  }

  /// Set the on demand (parathreads) queue max size.
  _i10.Configuration setOnDemandQueueMaxSize({required int new_}) {
    return _i10.Configuration(_i11.SetOnDemandQueueMaxSize(new_: new_));
  }

  /// Set the on demand (parathreads) fee variability.
  _i10.Configuration setOnDemandTargetQueueUtilization(
      {required _i13.Perbill new_}) {
    return _i10.Configuration(
        _i11.SetOnDemandTargetQueueUtilization(new_: new_));
  }

  /// Set the on demand (parathreads) ttl in the claimqueue.
  _i10.Configuration setOnDemandTtl({required int new_}) {
    return _i10.Configuration(_i11.SetOnDemandTtl(new_: new_));
  }

  /// Set the minimum backing votes threshold.
  _i10.Configuration setMinimumBackingVotes({required int new_}) {
    return _i10.Configuration(_i11.SetMinimumBackingVotes(new_: new_));
  }

  /// Set/Unset a node feature.
  _i10.Configuration setNodeFeature({
    required int index,
    required bool value,
  }) {
    return _i10.Configuration(_i11.SetNodeFeature(
      index: index,
      value: value,
    ));
  }

  /// Set approval-voting-params.
  _i10.Configuration setApprovalVotingParams(
      {required _i8.ApprovalVotingParams new_}) {
    return _i10.Configuration(_i11.SetApprovalVotingParams(new_: new_));
  }

  /// Set scheduler-params.
  _i10.Configuration setSchedulerParams({required _i9.SchedulerParams new_}) {
    return _i10.Configuration(_i11.SetSchedulerParams(new_: new_));
  }
}
