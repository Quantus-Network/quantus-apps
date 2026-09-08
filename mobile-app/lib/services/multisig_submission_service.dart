import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/pending_multisig_creations_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/multisig_creation_polling_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';

/// Everything a creation needs once on-chain checks have passed: the draft
/// account (with the resolved nonce) and the network fee it was checked with.
typedef MultisigCreationPreflight = ({MultisigAccount draft, BigInt networkFee});

class MultisigSubmissionService {
  MultisigSubmissionService(this._ref);

  final Ref _ref;

  /// On-chain preflight: address availability, fee estimate, and creator balance.
  ///
  /// Throws [MultisigAlreadyExistsException] if the predicted address already
  /// exists, or [MultisigInsufficientBalanceException] if the creator cannot
  /// afford pallet fee + network fee.
  Future<MultisigCreationPreflight> preflightMultisigCreation({
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
        .getFeeForCall(creator, buildCreateCall(draft))
        .then((data) => data.fee);

    final totalCost = MultisigCreationDraftFields.fromDraft(draft, networkFee: networkFee).totalCost;
    final balance = await _ref.read(substrateServiceProvider).queryBalance(creator.accountId);
    if (balance < totalCost) {
      throw MultisigInsufficientBalanceException(balance: balance, required: totalCost);
    }

    return (draft: draft, networkFee: networkFee);
  }

  /// The `create_multisig` call for [draft]; also the Keystone unsigned payload.
  RuntimeCall buildCreateCall(MultisigAccount draft) => _ref
      .read(multisigServiceProvider)
      .buildCreateMultisigCall(signers: draft.signers, threshold: draft.threshold, nonce: draft.nonce);

  /// Signs the creation with [creator]'s local key, submits it and tracks it.
  ///
  /// Awaits acceptance of the extrinsic by the chain before completing; indexer
  /// polling then continues in the background. Rethrows on submission failure
  /// so callers can surface the error instead of optimistically navigating away.
  Future<String> startMultisigCreation({required MultisigCreationPreflight preflight, required Account creator}) {
    final draft = preflight.draft;
    return _submitAndTrack(
      preflight,
      telemetryEvent: 'multisig_create_started',
      submit: () => _ref
          .read(multisigServiceProvider)
          .submitCreateMultisigExtrinsic(
            creator: creator,
            signers: draft.signers,
            threshold: draft.threshold,
            nonce: draft.nonce,
          ),
    );
  }

  /// Submits a creation signed off-device (Keystone) and tracks it.
  Future<String> submitExternallySignedMultisigCreation({
    required MultisigCreationPreflight preflight,
    required UnsignedTransactionData unsignedData,
    required Uint8List signatureWithPublicKey,
  }) {
    return _submitAndTrack(
      preflight,
      telemetryEvent: 'multisig_create_hardware',
      submit: () => _ref
          .read(substrateServiceProvider)
          .submitExtrinsicWithExternalSignature(unsignedData, signatureWithPublicKey),
    );
  }

  Future<String> _submitAndTrack(
    MultisigCreationPreflight preflight, {
    required String telemetryEvent,
    required Future<Uint8List> Function() submit,
  }) async {
    final draft = preflight.draft;
    final pending = _ref.read(pendingMultisigCreationsProvider.notifier);

    TelemetryService().sendEvent(telemetryEvent);
    await pending.add(PendingMultisigCreationEvent.fromDraft(draft, networkFee: preflight.networkFee), draft);

    try {
      quantusPrint('[MultisigSubmission] submitting creation for ${draft.accountId}');

      final extrinsicHash = '0x${hex.encode(await submit())}';
      quantusPrint('[MultisigSubmission] submitted $extrinsicHash');

      unawaited(pending.updateExtrinsicHash(draft.accountId, extrinsicHash));

      final submittedAt = pending.recordFor(draft.accountId)?.submittedAt;
      _ref.read(multisigCreationPollingServiceProvider).startPolling(draft, submittedAt: submittedAt);
      return extrinsicHash;
    } catch (e, stackTrace) {
      // Retries live in SubstrateService.submitExtrinsic (same signed bytes);
      // avoid outer retries here because each attempt re-signs with a fresh
      // nonce and can double-submit if a prior submit already landed.
      quantusPrint('[MultisigSubmission] submit failed: $e');
      quantusPrint('Stack trace: $stackTrace');
      TelemetryService().sendError('multisig_create_submit_failed', error: e);
      removePendingMultisigCreation(_ref, draft.accountId);
      rethrow;
    }
  }
}

final multisigSubmissionServiceProvider = Provider<MultisigSubmissionService>((ref) {
  return MultisigSubmissionService(ref);
});
