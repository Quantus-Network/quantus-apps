import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide DecodedCallView;
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/controllers/multisig_action_confirm_controller.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/decoded_call_view.dart';
import 'package:wallet_core/activity/decoded_call_headline.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';

/// Localized labels for a multisig confirmation sheet.
///
/// Resolved lazily against the current [AppLocalizations] so the sheet stays
/// correct if the locale changes while it is open.
class MultisigConfirmSheetLabels {
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;
  final String Function(AppLocalizations) confirmLabel;
  final String Function(AppLocalizations) dismissLabel;
  final String Function(AppLocalizations) failedMessage;

  const MultisigConfirmSheetLabels({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.dismissLabel,
    required this.failedMessage,
  });
}

/// Shared confirmation sheet for multisig proposal actions (approve, execute,
/// cancel): a view of the wallet_core confirmation of [kind].
///
/// [signer] is the local account that acts, chosen by the caller (after a
/// picker when more than one can).
///
/// Keystone (hardware) signers skip the approval and open the shared QR sign /
/// scan flow.
class MultisigActionConfirmSheet extends ConsumerWidget {
  final MultisigAccount msig;
  final MultisigProposal proposal;
  final MultisigActionKind kind;
  final MultisigConfirmSheetLabels labels;
  final ButtonVariant confirmVariant;

  /// The local account that acts.
  final Account signer;

  const MultisigActionConfirmSheet({
    super.key,
    required this.msig,
    required this.proposal,
    required this.kind,
    required this.labels,
    required this.signer,
    this.confirmVariant = ButtonVariant.primary,
  });

  MultisigActionRequest get _request =>
      MultisigActionRequest(kind: kind, msig: msig, proposal: proposal, signer: signer);

  /// Last resort when no call bytes are available at all: the indexer's own
  /// pallet/call names and transfer fields, with no invented parameters.
  DecodedCall get _fallbackTransferCall {
    final hasTransfer = proposal.amount != BigInt.zero || proposal.recipient.isNotEmpty;
    return DecodedCall(
      pallet: proposal.pallet,
      call: proposal.call,
      fields: const [],
      summary: hasTransfer
          ? TransferSummary(amount: proposal.amount, recipient: proposal.recipient.isEmpty ? null : proposal.recipient)
          : null,
    );
  }

  DecodedCallHeadline _headline(WidgetRef ref, AppLocalizations l10n, DecodedCall? decoded) {
    final fmt = ref.read(numberFormattingServiceProvider);
    return DecodedCallHeadline.of(
      decoded ?? _fallbackTransferCall,
      amountText: (token) => l10n.commonAmountBalance(
        fmt.formatBalance(token, smartDecimals: AppConstants.decimals),
        AppConstants.tokenSymbol,
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final provider = multisigActionConfirmProvider(_request);
    final outcome = await ref.read(provider.notifier).confirm();
    if (!context.mounted) return;

    switch (outcome) {
      case MultisigActionSubmitted():
        Navigator.pop(context);
      case MultisigActionNeedsHardwareSignature(:final session):
        // Take the QR screen's headline from the decoded call, so it agrees with
        // what this sheet showed — and does not claim "0 tokens" for a
        // non-transfer proposal.
        final headline = _headline(ref, ref.read(l10nProvider), ref.read(provider).decodedCall);
        final hash = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => KeystoneSignScreen(
              session: session(primaryDetail: headline.primary, secondaryDetail: headline.secondary),
            ),
          ),
        );
        if (!context.mounted) return;
        if (hash != null) Navigator.pop(context);
      case MultisigActionFailed() || MultisigActionDropped():
        return;
    }
  }

  String? _networkFeeLabel(AppLocalizations l10n, NumberFormattingService fmt, MultisigActionConfirmState state) {
    if (state.loadingFee) return '…';
    final fee = state.fee;
    if (fee == null) return null;
    return l10n.commonAmountBalance(
      fmt.formatBalance(fee, smartDecimals: AppConstants.decimals),
      AppConstants.tokenSymbol,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final state = ref.watch(multisigActionConfirmProvider(_request));
    final networkFeeLabel = _networkFeeLabel(l10n, fmt, state);
    final decoded = state.decodedCall;
    final headline = _headline(ref, l10n, decoded);
    final error = switch (state.error) {
      null => null,
      MultisigActionError.approvalRequired => l10n.multisigAuthRequired,
      MultisigActionError.submitFailed => labels.failedMessage(l10n),
    };

    return BottomSheetContainer(
      title: labels.title(l10n),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(labels.body(l10n), style: text.bodyLarge.copyWith(color: colors.textContent)),
          const SizedBox(height: 8),
          Text(headline.primary, style: text.titleScreen.copyWith(color: colors.textContent)),
          if (headline.secondary != null) ...[
            const SizedBox(height: 8),
            Text(headline.secondary!, style: text.body.copyWith(color: colors.textMuted)),
          ],
          if (state.loadingCall) ...[
            const SizedBox(height: 16),
            Text(l10n.multisigProposalCallLoading, style: text.caption.copyWith(color: colors.textMuted)),
          ],
          if (state.callUnavailable) ...[
            const SizedBox(height: 16),
            Text(l10n.multisigProposalCallUnavailable, style: text.caption.copyWith(color: colors.semanticEmber)),
          ],
          if (decoded != null && decoded.fields.isNotEmpty) ...[
            const SizedBox(height: 16),
            DecodedCallView(call: decoded),
          ],
          if (networkFeeLabel != null) ...[
            const SizedBox(height: 16),
            DetailSummaryRow.review(label: l10n.sendReviewNetworkFee, value: networkFeeLabel),
          ],
          if (state.feeUnavailable) ...[
            const SizedBox(height: 16),
            Text(l10n.multisigFeeEstimateUnavailable, style: text.caption.copyWith(color: colors.textMuted)),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
          ],
          const SizedBox(height: 24),
          QuantusButton.simple(
            label: labels.confirmLabel(l10n),
            variant: confirmVariant,
            isDisabled: !state.canConfirm,
            onTap: state.canConfirm ? () => _confirm(context, ref) : null,
          ),
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: labels.dismissLabel(l10n),
            variant: ButtonVariant.staged,
            isDisabled: state.submitting,
            onTap: state.submitting ? null : () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
