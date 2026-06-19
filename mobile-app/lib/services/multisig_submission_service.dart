import 'dart:async';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/multisig_creation_polling_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

class MultisigSubmissionService {
  MultisigSubmissionService(this._ref);

  final Ref _ref;

  /// On-chain preflight: address availability, fee estimate, and creator balance.
  ///
  /// Throws [MultisigAlreadyExistsException] if the predicted address already
  /// exists, or [MultisigInsufficientBalanceException] if the creator cannot
  /// afford pallet fee + network fee.
  Future<void> preflightMultisigCreation({
    required List<String> signers,
    required int threshold,
    required Account creator,
    BigInt? nonce,
  }) async {
    await _runCreationPreflight(name: '', signers: signers, threshold: threshold, creator: creator, nonce: nonce);
  }

  /// Preflight on-chain state, then submit and track creation.
  ///
  /// Awaits acceptance of the creation extrinsic by the chain before
  /// completing; indexer polling then continues in the background. Throws
  /// [MultisigAlreadyExistsException] if the predicted address already exists,
  /// or [MultisigInsufficientBalanceException] if the creator cannot afford
  /// the total creation cost. Rethrows on submission failure so callers can
  /// surface the error instead of optimistically navigating away.
  Future<void> startMultisigCreation({
    required String name,
    required List<String> signers,
    required int threshold,
    required Account creator,
    BigInt? nonce,
  }) async {
    final preflight = await _runCreationPreflight(
      name: name,
      signers: signers,
      threshold: threshold,
      creator: creator,
      nonce: nonce,
    );

    final draft = preflight.draft;
    final networkFee = preflight.networkFee;

    TelemetryService().sendEvent('multisig_create_started');
    await _ref
        .read(pendingMultisigCreationsProvider.notifier)
        .add(PendingMultisigCreationEvent.fromDraft(draft, networkFee: networkFee), draft);

    await _submitAndTrack(creator: creator, signers: signers, threshold: threshold, nonce: draft.nonce, draft: draft);
  }

  Future<void> _submitAndTrack({
    required Account creator,
    required List<String> signers,
    required int threshold,
    required BigInt nonce,
    required MultisigAccount draft,
  }) async {
    final service = _ref.read(multisigServiceProvider);
    try {
      quantusDebugPrint('[MultisigSubmission] submitting creation for ${draft.accountId}');

      final hashBytes = await service.submitCreateMultisigExtrinsic(
        creator: creator,
        signers: signers,
        threshold: threshold,
        nonce: nonce,
      );
      final extrinsicHash = '0x${hex.encode(hashBytes)}';
      quantusDebugPrint('[MultisigSubmission] submitted $extrinsicHash');

      unawaited(
        _ref.read(pendingMultisigCreationsProvider.notifier).updateExtrinsicHash(draft.accountId, extrinsicHash),
      );

      final submittedAt = _ref.read(pendingMultisigCreationsProvider.notifier).recordFor(draft.accountId)?.submittedAt;
      _ref.read(multisigCreationPollingServiceProvider).startPolling(draft, submittedAt: submittedAt);
    } catch (e, stackTrace) {
      // Retries live in SubstrateService.submitExtrinsic (same signed bytes);
      // avoid outer retries here because each attempt re-signs with a fresh
      // nonce and can double-submit if a prior submit already landed.
      quantusDebugPrint('[MultisigSubmission] submit failed: $e');
      quantusDebugPrint('Stack trace: $stackTrace');
      TelemetryService().sendError('multisig_create_submit_failed', error: e, stackTrace: stackTrace);
      removePendingMultisigCreation(_ref, draft.accountId);
      rethrow;
    }
  }

  Future<({MultisigAccount draft, BigInt networkFee})> _runCreationPreflight({
    required String name,
    required List<String> signers,
    required int threshold,
    required Account creator,
    BigInt? nonce,
  }) async {
    final service = _ref.read(multisigServiceProvider);
    final effectiveNonce = nonce ?? MultisigService.defaultMultisigNonce;

    final predictedAddress = await service.predictMultisigAddress(
      signers: signers,
      threshold: threshold,
      nonce: effectiveNonce,
    );

    if (await service.isMultisigIndexed(predictedAddress)) {
      throw MultisigAlreadyExistsException(predictedAddress);
    }

    final draft = MultisigAccount(
      name: name,
      accountId: predictedAddress,
      signers: signers,
      threshold: threshold,
      nonce: effectiveNonce,
      myMemberAccountId: creator.accountId,
      creator: creator.accountId,
    );

    final networkFee = await _ref
        .read(substrateServiceProvider)
        .getFeeForCall(
          creator,
          service.buildCreateMultisigCall(signers: signers, threshold: threshold, nonce: effectiveNonce),
        )
        .then((data) => data.fee);

    final totalCost = MultisigCreationDraftFields.fromDraft(draft, networkFee: networkFee).totalCost;
    final balance = await _ref.read(substrateServiceProvider).queryBalance(creator.accountId);
    if (balance < totalCost) {
      throw MultisigInsufficientBalanceException(balance: balance, required: totalCost);
    }

    return (draft: draft, networkFee: networkFee);
  }
}

final multisigSubmissionServiceProvider = Provider<MultisigSubmissionService>((ref) {
  return MultisigSubmissionService(ref);
});
