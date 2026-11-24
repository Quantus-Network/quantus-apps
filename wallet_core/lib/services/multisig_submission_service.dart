import 'dart:async';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/pending_multisig_creations_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/services/multisig_creation_polling_service.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_session.dart';

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
  /// afford pallet fee + network fee from what it can spend: the chain's
  /// balance less what it has pending ([pendingOutgoingOf]).
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
    final onChain = await _ref.read(substrateServiceProvider).queryBalance(creator.accountId);
    final spendable = onChain - await pendingOutgoingOf(_ref, creator.accountId);
    if (spendable < totalCost) {
      throw MultisigInsufficientBalanceException(
        balance: spendable < BigInt.zero ? BigInt.zero : spendable,
        required: totalCost,
      );
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

  /// The signing of [preflight]'s creation on [creator]'s cold wallet: what
  /// the cold wallet must show, the call it signs, and the submission of its
  /// signature, tracked as [startMultisigCreation]'s is. A signature that
  /// comes back after a wallet reset is refused.
  KeystoneSigningSession creationSigningSession({
    required MultisigCreationPreflight preflight,
    required Account creator,
  }) {
    final l10n = _ref.read(l10nProvider);
    final draft = preflight.draft;
    // Taken now: the signature can come back long after, past a wallet reset.
    final walletSession = _ref.read(walletSessionProvider);
    final ticket = walletSession.ticket;
    return KeystoneSigningSession(
      account: creator,
      buildCall: () => buildCreateCall(draft),
      primaryLabel: l10n.keystoneSignActionLabel,
      primaryDetail: l10n.multisigCreateKeystoneAction(draft.threshold, draft.signers.length),
      secondaryLabel: l10n.multisigCreatePredictedAddressLabel,
      secondaryDetail: draft.accountId,
      secondaryIsAddress: true,
      cacheKey: KeystoneSignCacheKey.forExtrinsic(accountId: creator.accountId, identity: 'create|${draft.accountId}'),
      telemetryPrefix: 'multisig_create_hardware',
      submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async {
        if (!walletSession.isCurrent(ticket)) {
          throw StateError('The wallet was reset before this multisig\'s creation was signed');
        }
        return submitExternallySignedMultisigCreation(
          preflight: preflight,
          unsignedData: unsignedData,
          signatureWithPublicKey: signatureWithPublicKey,
        );
      },
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

    _ref.read(telemetryProvider).sendEvent(telemetryEvent);
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
      _ref.read(telemetryProvider).sendError('multisig_create_submit_failed', error: e);
      removePendingMultisigCreation(_ref, draft.accountId);
      rethrow;
    }
  }
}

final multisigSubmissionServiceProvider = Provider<MultisigSubmissionService>((ref) {
  return MultisigSubmissionService(ref);
});
