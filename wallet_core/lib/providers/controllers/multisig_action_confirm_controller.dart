import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/utils/account_utils.dart';

/// An action on a multisig proposal that this wallet confirms and sends.
enum MultisigActionKind { approve, execute, cancel }

/// The call bytes an action that resubmits the proposal cannot proceed without.
///
/// [action] names the caller so a missing load is not mistaken for a chain
/// rejection.
List<int> requireCallBytes(List<int>? callBytes, String action) {
  if (callBytes == null) throw StateError('$action requires the proposal call bytes');
  return callBytes;
}

/// What is being confirmed: [kind] on [proposal] of [msig], by [signer].
class MultisigActionRequest {
  final MultisigActionKind kind;
  final MultisigAccount msig;
  final MultisigProposal proposal;
  final Account signer;

  const MultisigActionRequest({required this.kind, required this.msig, required this.proposal, required this.signer});

  @override
  bool operator ==(Object other) =>
      other is MultisigActionRequest &&
      other.kind == kind &&
      other.msig.accountId == msig.accountId &&
      other.proposal.id == proposal.id &&
      other.signer.accountId == signer.accountId;

  @override
  int get hashCode => Object.hash(kind, msig.accountId, proposal.id, signer.accountId);
}

/// Why a confirmation did not go out.
enum MultisigActionError {
  /// The person at the device did not approve it.
  approvalRequired,

  /// The chain did not take it.
  submitFailed,

  /// The signer's account cannot pay the network fee.
  feePayerInsufficient,
}

class MultisigActionConfirmState {
  final bool loadingCall;

  /// The proposal's call could not be read from the chain, or did not decode:
  /// nothing may be built from it.
  final bool callUnavailable;

  /// The proposal's call as stored on chain, kept only once it decoded.
  final List<int>? callBytes;
  final DecodedCall? decodedCall;

  final bool loadingFee;
  final BigInt? fee;
  final bool feeUnavailable;

  /// What the signer's account can spend, once known.
  final BigInt? signerBalance;

  final bool submitting;
  final MultisigActionError? error;

  const MultisigActionConfirmState({
    this.loadingCall = true,
    this.callUnavailable = false,
    this.callBytes,
    this.decodedCall,
    this.loadingFee = true,
    this.fee,
    this.feeUnavailable = false,
    this.signerBalance,
    this.submitting = false,
    this.error,
  });

  /// The signer's account holds less than the fee. A fee or a balance not
  /// known is no objection, as when proposing.
  bool get cannotPayFee => _cannotPay(signerBalance, fee);

  /// Never while the call is not known to be the one stored on chain, nor
  /// while the signer cannot pay the fee.
  bool get canConfirm => !submitting && !loadingCall && !callUnavailable && !cannotPayFee;

  MultisigActionConfirmState copyWith({
    bool? loadingCall,
    bool? callUnavailable,
    List<int>? callBytes,
    DecodedCall? decodedCall,
    bool? loadingFee,
    BigInt? fee,
    bool? feeUnavailable,
    BigInt? Function()? signerBalance,
    bool? submitting,
    MultisigActionError? Function()? error,
  }) => MultisigActionConfirmState(
    loadingCall: loadingCall ?? this.loadingCall,
    callUnavailable: callUnavailable ?? this.callUnavailable,
    callBytes: callBytes ?? this.callBytes,
    decodedCall: decodedCall ?? this.decodedCall,
    loadingFee: loadingFee ?? this.loadingFee,
    fee: fee ?? this.fee,
    feeUnavailable: feeUnavailable ?? this.feeUnavailable,
    signerBalance: signerBalance != null ? signerBalance() : this.signerBalance,
    submitting: submitting ?? this.submitting,
    error: error != null ? error() : this.error,
  );
}

bool _cannotPay(BigInt? balance, BigInt? fee) => balance != null && fee != null && balance < fee;

/// Thrown by a hardware signing session instead of broadcasting, when the
/// signer's account can no longer pay the fee it was signed with.
class SignerCannotPayFee implements Exception {
  const SignerCannotPayFee();

  @override
  String toString() => 'SignerCannotPayFee: the signer\'s account cannot pay the network fee';
}

sealed class MultisigActionOutcome {
  const MultisigActionOutcome();
}

/// Sent in the transaction of [hash].
final class MultisigActionSubmitted extends MultisigActionOutcome {
  final String hash;

  const MultisigActionSubmitted(this.hash);
}

/// The signer signs on a Keystone: [session] hands the action to the QR flow,
/// headed by the details the caller words.
final class MultisigActionNeedsHardwareSignature extends MultisigActionOutcome {
  final KeystoneSigningSession Function({required String primaryDetail, String? secondaryDetail}) session;

  const MultisigActionNeedsHardwareSignature(this.session);
}

final class MultisigActionFailed extends MultisigActionOutcome {
  final MultisigActionError error;

  const MultisigActionFailed(this.error);
}

/// The confirmation was closed while it waited, and nothing went out.
final class MultisigActionDropped extends MultisigActionOutcome {
  const MultisigActionDropped();
}

/// Confirms an action on a multisig proposal: reads the proposal's call from
/// the chain, estimates the fee, asks the person at the device, and sends it.
///
/// `multisig.approve` and `multisig.execute` only count a submission whose
/// call is byte-equal to the stored proposal, so the call comes from chain
/// storage, never the indexer; the fee is estimated after it, since the
/// approve fee scales with its size.
class MultisigActionConfirmController extends Notifier<MultisigActionConfirmState> {
  MultisigActionConfirmController(this.request);

  final MultisigActionRequest request;

  MultisigAccount get _msig => request.msig;
  MultisigProposal get _proposal => request.proposal;
  String get _logPrefix => '[Multisig ${request.kind.name}]';

  @override
  MultisigActionConfirmState build() {
    final balance = effectiveBalanceProviderFamily(request.signer.accountId);
    ref.listen(balance, (_, next) => state = state.copyWith(signerBalance: () => next.value));
    unawaited(Future.microtask(_prepare));
    return MultisigActionConfirmState(signerBalance: ref.read(balance).value);
  }

  /// The signer's account cannot pay the fee, as it stands now.
  bool _cannotPayNow() =>
      _cannotPay(ref.read(effectiveBalanceProviderFamily(request.signer.accountId)).value, state.fee);

  Future<void> _prepare() async {
    final List<int> bytes;
    final DecodedCall decoded;
    try {
      bytes = await ref.read(multisigServiceProvider).fetchProposalCallBytes(msig: _msig, proposalId: _proposal.id);
      decoded = MultisigProposal.decodeProposalCall(bytes);
    } catch (e, st) {
      quantusPrint('$_logPrefix proposal call unavailable: $e $st');
      if (!ref.mounted) return;
      state = state.copyWith(loadingCall: false, callUnavailable: true, loadingFee: false);
      return;
    }
    if (!ref.mounted) return;
    state = state.copyWith(loadingCall: false, callBytes: bytes, decodedCall: decoded);

    try {
      final fee = await _estimateFee(request.signer, bytes);
      if (!ref.mounted) return;
      state = state.copyWith(loadingFee: false, fee: fee);
    } catch (e, st) {
      quantusPrint('$_logPrefix fee estimate error: $e $st');
      if (!ref.mounted) return;
      state = state.copyWith(loadingFee: false, feeUnavailable: true);
    }
  }

  Future<BigInt> _estimateFee(Account signer, List<int> callBytes) {
    final service = ref.read(multisigServiceProvider);
    return switch (request.kind) {
      MultisigActionKind.approve => service.estimateApproveFee(
        msig: _msig,
        signer: signer,
        proposalId: _proposal.id,
        callBytes: callBytes,
      ),
      MultisigActionKind.execute => service.estimateExecuteFee(
        msig: _msig,
        signer: signer,
        proposalId: _proposal.id,
        callBytes: callBytes,
      ),
      MultisigActionKind.cancel => service.estimateCancelFee(msig: _msig, signer: signer, proposalId: _proposal.id),
    };
  }

  String _authReason(AppLocalizations l10n) => switch (request.kind) {
    MultisigActionKind.approve => l10n.multisigApproveAuthReason,
    MultisigActionKind.execute => l10n.multisigExecuteAuthReason,
    MultisigActionKind.cancel => l10n.multisigCancelAuthReason,
  };

  /// Sends the action, once the person at the device approves it; a Keystone
  /// signer is handed to the QR flow instead.
  Future<MultisigActionOutcome> confirm() async {
    // What the signer holds can have moved since the review was drawn, and
    // again while the approval was asked for.
    if (_cannotPayNow()) return _fail(MultisigActionError.feePayerInsufficient);
    if (!state.canConfirm) throw StateError('$_logPrefix confirmed before it could be');
    state = state.copyWith(submitting: true, error: () => null);

    final signer = request.signer;
    if (signer.signsWithHardware) {
      state = state.copyWith(submitting: false);
      return MultisigActionNeedsHardwareSignature(
        ({required primaryDetail, secondaryDetail}) => _hardwareSession(signer, primaryDetail, secondaryDetail),
      );
    }

    final ApprovalResult approval;
    try {
      approval = await ref.read(userApprovalProvider).approve(reason: _authReason(ref.read(l10nProvider)));
    } catch (e, st) {
      // The system could not ask (a prompt that cannot be shown, a login
      // check that failed to run): nothing went out, as when sending.
      quantusPrint('$_logPrefix approval failed: $e $st');
      if (!ref.mounted) return const MultisigActionDropped();
      return _fail(MultisigActionError.submitFailed);
    }
    if (!ref.mounted) return const MultisigActionDropped();
    if (approval != ApprovalResult.approved) return _fail(MultisigActionError.approvalRequired);
    if (_cannotPayNow()) return _fail(MultisigActionError.feePayerInsufficient);

    try {
      final hash = await _submit(signer);
      if (ref.mounted) _refreshProposals();
      return MultisigActionSubmitted(hash);
    } catch (e, st) {
      quantusPrint('$_logPrefix submit error: $e $st');
      if (!ref.mounted) return const MultisigActionFailed(MultisigActionError.submitFailed);
      return _fail(MultisigActionError.submitFailed);
    }
  }

  MultisigActionFailed _fail(MultisigActionError error) {
    state = state.copyWith(submitting: false, error: () => error);
    return MultisigActionFailed(error);
  }

  Future<String> _submit(Account signer) {
    final submission = ref.read(transactionSubmissionServiceProvider);
    return switch (request.kind) {
      MultisigActionKind.approve => submission.approveProposal(
        msig: _msig,
        signer: signer,
        proposal: _proposal,
        callBytes: state.callBytes,
      ),
      MultisigActionKind.execute => submission.executeProposal(
        msig: _msig,
        signer: signer,
        proposal: _proposal,
        callBytes: state.callBytes,
        fee: state.fee,
      ),
      MultisigActionKind.cancel => submission.cancelProposal(
        msig: _msig,
        proposer: signer,
        proposal: _proposal,
        fee: state.fee,
      ),
    };
  }

  void _refreshProposals() {
    ref.invalidate(multisigOpenProposalsProvider(_msig));
    ref.invalidate(multisigCurrentBlockProvider);
  }

  RuntimeCall _buildCall() {
    return switch (request.kind) {
      MultisigActionKind.approve => MultisigService().buildApproveCall(
        msig: _msig,
        proposalId: _proposal.id,
        call: requireCallBytes(state.callBytes, 'Approve'),
      ),
      MultisigActionKind.execute => MultisigService().buildExecuteCall(
        msig: _msig,
        proposalId: _proposal.id,
        call: requireCallBytes(state.callBytes, 'Execute'),
      ),
      MultisigActionKind.cancel => MultisigService().buildCancelCall(msig: _msig, proposalId: _proposal.id),
    };
  }

  KeystoneSigningSession _hardwareSession(Account signer, String primaryDetail, String? secondaryDetail) {
    final kind = request.kind.name;
    final fee = state.fee;
    return KeystoneSigningSession(
      account: signer,
      buildCall: _buildCall,
      primaryDetail: primaryDetail,
      secondaryDetail: secondaryDetail,
      cacheKey: KeystoneSignCacheKey.forExtrinsic(
        accountId: signer.accountId,
        identity: '$kind|${_msig.accountId}|${_proposal.id}',
      ),
      telemetryPrefix: 'multisig_$kind',
      submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async {
        // What the signer holds can have moved while the Keystone signed.
        if (_cannotPay(ref.read(effectiveBalanceProviderFamily(signer.accountId)).value, fee)) {
          throw const SignerCannotPayFee();
        }
        final submission = ref.read(transactionSubmissionServiceProvider);
        final hash = await switch (request.kind) {
          MultisigActionKind.approve => submission.approveProposalWithExternalSignature(
            msig: _msig,
            signer: signer,
            proposal: _proposal,
            unsignedData: unsignedData,
            signatureWithPublicKey: signatureWithPublicKey,
          ),
          MultisigActionKind.execute => submission.executeProposalWithExternalSignature(
            msig: _msig,
            signer: signer,
            proposal: _proposal,
            unsignedData: unsignedData,
            signatureWithPublicKey: signatureWithPublicKey,
            fee: fee,
          ),
          MultisigActionKind.cancel => submission.cancelProposalWithExternalSignature(
            msig: _msig,
            proposer: signer,
            proposal: _proposal,
            unsignedData: unsignedData,
            signatureWithPublicKey: signatureWithPublicKey,
            fee: fee,
          ),
        };
        ref.invalidate(multisigOpenProposalsProvider(_msig));
        ref.invalidate(multisigCurrentBlockProvider);
        return hash;
      },
    );
  }
}

/// One confirmation per request, for as long as something watches it.
final multisigActionConfirmProvider = NotifierProvider.autoDispose
    .family<MultisigActionConfirmController, MultisigActionConfirmState, MultisigActionRequest>(
      MultisigActionConfirmController.new,
    );
