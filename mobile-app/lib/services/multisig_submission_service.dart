import 'dart:async';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_creation_toast_provider.dart';
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
  /// afford pallet fee + network fee + deposit.
  Future<void> preflightMultisigCreation({
    required List<String> signers,
    required int threshold,
    required Account creator,
    BigInt? nonce,
  }) async {
    await _runCreationPreflight(
      name: '',
      signers: signers,
      threshold: threshold,
      creator: creator,
      nonce: nonce,
    );
  }

  /// Preflight on-chain state, then submit and track creation in the background.
  ///
  /// Returns when preflight passes and background work is scheduled. Throws
  /// [MultisigAlreadyExistsException] if the predicted address already exists,
  /// or [MultisigInsufficientBalanceException] if the creator cannot afford
  /// the total creation cost.
  Future<void> startMultisigCreation({
    required String name,
    required List<String> signers,
    required int threshold,
    required Account creator,
    BigInt? nonce,
    int maxRetries = 3,
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
    addPendingMultisigCreation(_ref, PendingMultisigCreationEvent.fromDraft(draft, networkFee: networkFee));

    unawaited(
      _submitAndTrackBackground(
        creator: creator,
        signers: signers,
        threshold: threshold,
        nonce: draft.nonce,
        draft: draft,
        maxRetries: maxRetries,
      ),
    );
  }

  Future<void> _submitAndTrackBackground({
    required Account creator,
    required List<String> signers,
    required int threshold,
    required BigInt nonce,
    required MultisigAccount draft,
    required int maxRetries,
    int attempt = 1,
  }) async {
    final service = _ref.read(multisigServiceProvider);
    try {
      quantusDebugPrint('[MultisigSubmission] submit attempt $attempt/$maxRetries for ${draft.accountId}');

      final hashBytes = await service.submitCreateMultisigExtrinsic(
        creator: creator,
        signers: signers,
        threshold: threshold,
        nonce: nonce,
      );
      final extrinsicHash = '0x${hex.encode(hashBytes)}';
      quantusDebugPrint('[MultisigSubmission] submitted $extrinsicHash');

      _ref.read(multisigCreationPollingServiceProvider).startPolling(draft);
    } catch (e, stackTrace) {
      quantusDebugPrint('[MultisigSubmission] submit failed attempt $attempt: $e');

      if (attempt < maxRetries) {
        await Future<void>.delayed(const Duration(seconds: 2));
        await _submitAndTrackBackground(
          creator: creator,
          signers: signers,
          threshold: threshold,
          nonce: nonce,
          draft: draft,
          maxRetries: maxRetries,
          attempt: attempt + 1,
        );
        return;
      }

      quantusDebugPrint('[MultisigSubmission] failed after $maxRetries attempts: $e');
      quantusDebugPrint('Stack trace: $stackTrace');
      removePendingMultisigCreation(_ref, draft.accountId);
      _ref.read(multisigCreationToastProvider.notifier).state = const MultisigCreationToastEvent(
        MultisigCreationToastKind.submitFailed,
      );
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

    if (await service.isMultisigOnChain(predictedAddress)) {
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

    final totalCost = PendingMultisigCreationEvent.fromDraft(draft, networkFee: networkFee).totalCost;
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
