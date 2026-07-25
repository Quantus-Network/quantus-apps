import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/multisig_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/detail_summary_row.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Estimates the network fee for the action being confirmed.
typedef MultisigConfirmFeeEstimator = Future<BigInt> Function(WidgetRef ref, Account signer);

/// Submits the action being confirmed (software / local mnemonic path).
typedef MultisigConfirmSubmitter = Future<void> Function(WidgetRef ref, Account signer, BigInt? fee);

/// Builds the runtime call for the action (used for Keystone unsigned payloads).
typedef MultisigConfirmCallBuilder = RuntimeCall Function(Account signer);

/// Submits a hardware-signed extrinsic for the action.
typedef MultisigConfirmExternalSubmitter =
    Future<String> Function(
      WidgetRef ref, {
      required Account signer,
      required UnsignedTransactionData unsignedData,
      required Uint8List signature,
      required Uint8List publicKey,
      BigInt? fee,
    });

/// Localized labels for a multisig confirmation sheet.
///
/// Resolved lazily against the current [AppLocalizations] so the sheet stays
/// correct if the locale changes while it is open.
class MultisigConfirmSheetLabels {
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
  final String Function(AppLocalizations) confirmLabel;
  final String Function(AppLocalizations) dismissLabel;
  final String Function(AppLocalizations) authReason;
  final String Function(AppLocalizations) failedMessage;

  const MultisigConfirmSheetLabels({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.dismissLabel,
    required this.authReason,
    required this.failedMessage,
  });
}

/// Shared confirmation sheet for multisig proposal actions (approve, execute,
/// cancel).
///
/// Handles signer lookup, fee estimation, local authentication, and submission;
/// callers supply only labels and the action-specific callbacks.
///
/// When multiple local accounts are members of the multisig, pass [signer]
/// explicitly (e.g. after a picker). Otherwise the sheet falls back to
/// [MultisigAccount.myMemberAccountId].
///
/// Keystone (hardware) signers skip local biometric auth and open the shared
/// QR sign / scan flow built from [buildCall] + [submitExternal].
class MultisigActionConfirmSheet extends ConsumerStatefulWidget {
  final MultisigAccount msig;
  final MultisigProposal proposal;
  final MultisigConfirmSheetLabels labels;
  final MultisigConfirmFeeEstimator estimateFee;
  final MultisigConfirmSubmitter submit;
  final MultisigConfirmCallBuilder buildCall;
  final MultisigConfirmExternalSubmitter submitExternal;
  final ButtonVariant confirmVariant;

  /// Explicit signer when the caller already resolved which local account acts.
  final Account? signer;

  /// Prefix for debug log messages, e.g. `[MultisigApprove]`.
  final String logPrefix;

  /// Telemetry prefix for the Keystone path, e.g. `multisig_approve`.
  final String hardwareTelemetryPrefix;

  /// Cache identity suffix for the Keystone payload (action + proposal id).
  final String hardwareCacheIdentity;

  const MultisigActionConfirmSheet({
    super.key,
    required this.msig,
    required this.proposal,
    required this.labels,
    required this.estimateFee,
    required this.submit,
    required this.buildCall,
    required this.submitExternal,
    required this.logPrefix,
    required this.hardwareTelemetryPrefix,
    required this.hardwareCacheIdentity,
    this.signer,
    this.confirmVariant = ButtonVariant.primary,
  });

  @override
  ConsumerState<MultisigActionConfirmSheet> createState() => _MultisigActionConfirmSheetState();
}

class _MultisigActionConfirmSheetState extends ConsumerState<MultisigActionConfirmSheet> {
  bool _submitting = false;
  String? _errorMessage;
  BigInt? _networkFee;
  bool _loadingFee = true;
  bool _feeEstimateFailed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNetworkFee());
  }

  Account _requireSigner() {
    if (widget.signer != null) return widget.signer!;

    final signer = ref
        .read(accountsProvider)
        .value
        ?.firstWhere(
          (a) => a.accountId == widget.msig.myMemberAccountId,
          orElse: () => throw Exception('Member account not found in local wallet'),
        );
    if (signer == null) throw Exception('No signer account available');
    return signer;
  }

  bool _isHardwareSigner(Account signer) {
    return signer.accountType == AccountType.keystone || AppConstants.debugHardwareWallet;
  }

  Future<void> _loadNetworkFee() async {
    try {
      final fee = await widget.estimateFee(ref, _requireSigner());

      if (!mounted) return;
      setState(() {
        _networkFee = fee;
        _loadingFee = false;
      });
    } catch (e, st) {
      quantusDebugPrint('${widget.logPrefix} fee estimate error: $e $st');
      if (!mounted) return;
      setState(() {
        _loadingFee = false;
        _feeEstimateFailed = true;
      });
    }
  }

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final l10n = ref.read(l10nProvider);
    final signer = _requireSigner();

    // Hardware accounts sign off-device via QR — same path as regular transfers.
    if (_isHardwareSigner(signer)) {
      await _confirmWithHardware(signer, l10n);
      return;
    }

    final authed = await LocalAuthService().authenticate(localizedReason: widget.labels.authReason(l10n));
    if (!mounted) return;
    if (!authed) {
      setState(() {
        _submitting = false;
        _errorMessage = l10n.multisigAuthRequired;
      });
      return;
    }

    try {
      await widget.submit(ref, signer, _networkFee);

      if (!mounted) return;
      ref.invalidate(multisigOpenProposalsProvider(widget.msig));
      ref.invalidate(multisigCurrentBlockProvider);
      Navigator.pop(context);
    } catch (e, st) {
      quantusDebugPrint('${widget.logPrefix} submit error: $e $st');
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = widget.labels.failedMessage(l10n);
      });
    }
  }

  Future<void> _confirmWithHardware(Account signer, AppLocalizations l10n) async {
    final fmt = ref.read(numberFormattingServiceProvider);
    final amountText = l10n.commonAmountBalance(
      fmt.formatBalance(widget.proposal.amount, smartDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
    final recipient = widget.proposal.recipient;

    final session = KeystoneSigningSession(
      account: signer,
      buildCall: () => widget.buildCall(signer),
      title: widget.labels.title(l10n),
      primaryDetail: amountText,
      secondaryDetail: recipient.isEmpty ? null : recipient,
      cacheKey: KeystoneSignCacheKey.forExtrinsic(accountId: signer.accountId, identity: widget.hardwareCacheIdentity),
      telemetryPrefix: widget.hardwareTelemetryPrefix,
      submitSigned: (ref, {required unsignedData, required signature, required publicKey}) {
        return widget.submitExternal(
          ref,
          signer: signer,
          unsignedData: unsignedData,
          signature: signature,
          publicKey: publicKey,
          fee: _networkFee,
        );
      },
    );

    setState(() => _submitting = false);

    final hash = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => KeystoneSignScreen(session: session)));

    if (!mounted) return;
    if (hash != null) {
      ref.invalidate(multisigOpenProposalsProvider(widget.msig));
      ref.invalidate(multisigCurrentBlockProvider);
      Navigator.pop(context);
    }
  }

  String? _networkFeeLabel(AppLocalizations l10n, NumberFormattingService fmt) {
    if (_loadingFee) return '…';
    if (_networkFee == null) return null;
    return l10n.commonAmountBalance(
      fmt.formatBalance(_networkFee!, smartDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colors;
    final text = context.themeText;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final valueStyle = text.transactionDetailRowLabel;
    final amountText = l10n.commonAmountBalance(
      fmt.formatBalance(widget.proposal.amount, smartDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
    final recipient = AddressFormattingService.formatActivityDetailAddress(widget.proposal.recipient);
    final networkFeeLabel = _networkFeeLabel(l10n, fmt);

    return BottomSheetContainer(
      title: widget.labels.title(l10n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Text(widget.labels.body(l10n), style: text.paragraph?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text(amountText, style: text.smallTitle?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text(
            l10n.multisigApproveConfirmTo(recipient),
            style: text.smallParagraph?.copyWith(color: colors.textTertiary),
          ),
          if (networkFeeLabel != null) ...[
            const SizedBox(height: 16),
            DetailSummaryRow.review(label: l10n.sendReviewNetworkFee, value: networkFeeLabel, valueStyle: valueStyle),
          ],
          if (_feeEstimateFailed) ...[
            const SizedBox(height: 16),
            Text(l10n.multisigFeeEstimateUnavailable, style: text.detail?.copyWith(color: colors.textTertiary)),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
          ],
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: widget.labels.confirmLabel(l10n),
            variant: widget.confirmVariant,
            isDisabled: _submitting,
            onTap: _submitting ? null : _confirm,
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: widget.labels.dismissLabel(l10n),
            variant: ButtonVariant.secondary,
            isDisabled: _submitting,
            onTap: _submitting ? null : () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
