import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/encrypted_send_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/wormhole_progress_steps.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_terminal_screen.dart';

/// Renders an encrypted send driven by [encryptedSendControllerProvider]: the
/// controller owns the operation (revalidation, proving, submission, cancel);
/// this screen only starts it, displays its state and navigates to the shared
/// terminal screen on success.
///
/// There is no retry here — after a partial submission the plan is stale
/// (some inputs are spent), so the user re-initiates from Home against the
/// refreshed UTXO set instead.
class EncryptedSendProgressScreen extends ConsumerStatefulWidget {
  final Account account;
  final WormholeSpendPlan plan;

  /// The amount the user confirmed at review; the controller refuses to prove
  /// a plan whose amountToken differs.
  final BigInt amount;
  final String recipientAddress;
  final SendTerminalContent terminal;

  const EncryptedSendProgressScreen({
    super.key,
    required this.account,
    required this.plan,
    required this.amount,
    required this.recipientAddress,
    required this.terminal,
  });

  @override
  ConsumerState<EncryptedSendProgressScreen> createState() => _EncryptedSendProgressScreenState();
}

class _EncryptedSendProgressScreenState extends ConsumerState<EncryptedSendProgressScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred so the provider is not mutated during widget construction.
    Future.microtask(() {
      if (!mounted) return;
      unawaited(
        ref
            .read(encryptedSendControllerProvider.notifier)
            .start(
              account: widget.account,
              plan: widget.plan,
              amount: widget.amount,
              recipientAddress: widget.recipientAddress,
            ),
      );
    });
  }

  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final l10n = ref.watch(l10nProvider);
    final send = ref.watch(encryptedSendControllerProvider);

    ref.listen(encryptedSendControllerProvider, (previous, next) {
      if (next.phase == EncryptedSendPhase.succeeded && previous?.phase != EncryptedSendPhase.succeeded) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SendTerminalScreen(content: widget.terminal)),
        );
      }
    });

    final running = send.isRunning || send.phase == EncryptedSendPhase.idle;
    final cancelled = send.phase == EncryptedSendPhase.cancelled;
    final errorMessage = switch (send.phase) {
      EncryptedSendPhase.planStale => l10n.encryptedSendPlanStale,
      EncryptedSendPhase.failed => send.errorMessage,
      _ => null,
    };

    return PopScope(
      // After an error or cancel the spend plan is stale (inputs may already
      // be spent), so leaving always returns Home — never back to the review
      // screen, whose Confirm would resubmit the same plan.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || running) return;
        _goHome();
      },
      child: ScaffoldBase(
        appBar: V2AppBar(
          title: errorMessage != null
              ? l10n.encryptedSendFailedTitle
              : cancelled
              ? l10n.encryptedSendCancelledTitle
              : l10n.encryptedSendProgressTitle,
          showBackButton: false,
          leading: running ? null : AppBackButton(onTap: _goHome),
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            _buildStatusHeader(colors, text, l10n),
            const SizedBox(height: 24),
            WormholeProgressSteps(
              steps: [
                (1, l10n.encryptedSendStepPreparing),
                (4, l10n.encryptedSendStepGenerating),
                (5, l10n.encryptedSendStepProving),
                (6, l10n.encryptedSendStepSubmitting),
              ],
              stepProgress: send.stepProgress,
              currentStep: send.currentStep,
              done: false,
              cancelled: cancelled,
              hasError: errorMessage != null,
            ),
            if (errorMessage != null) ...[const SizedBox(height: 24), _buildErrorBanner(colors, text, errorMessage)],
            if (cancelled && send.submittedRecipientToken > BigInt.zero) ...[
              const SizedBox(height: 24),
              _buildPartialCancelNotice(colors, text, l10n, send.submittedRecipientToken),
            ],
          ],
        ),
        bottomContent: _buildBottomContent(colors, text, l10n, send, running),
      ),
    );
  }

  Widget _buildStatusHeader(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountLabel = fmt.formatBalance(widget.plan.amountToken, maxDecimals: 2, addSymbol: true);
    final shortAddr = AddressFormattingService.formatAddress(widget.recipientAddress.trim());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.encryptedSendingLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 16),
          Text(amountLabel, style: text.conversionAmountPrimary?.copyWith(fontSize: 32, color: colors.textPrimary)),
          const SizedBox(height: 16),
          if (widget.terminal.recipientChecksum != null) ...[
            Text(
              widget.terminal.recipientChecksum!,
              style: text.transactionDetailRowValue?.copyWith(color: colors.checksum),
            ),
            const SizedBox(height: 4),
          ],
          Text(shortAddr, style: text.transactionDetailRowValue?.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(AppColorsV2 colors, AppTextTheme text, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.textError.useOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textError.useOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.textError, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: text.detail?.copyWith(color: colors.textError)),
          ),
        ],
      ),
    );
  }

  Widget _buildPartialCancelNotice(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n, BigInt submitted) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amount = fmt.formatBalance(submitted, maxDecimals: 2, addSymbol: true);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colors.textSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.encryptedSendCancelledPartial(amount),
              style: text.detail?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  double _overallProgress(EncryptedSendState send) {
    const displaySteps = [1, 4, 5, 6];
    int completed = 0;
    for (final id in displaySteps) {
      final p = send.stepProgress[id];
      if (p != null && p.total != null && p.completed >= p.total!) {
        completed++;
      } else if (p != null && send.currentStep > id) {
        completed++;
      }
    }
    return (completed / displaySteps.length).clamp(0.0, 1.0);
  }

  Widget _buildBottomContent(
    AppColorsV2 colors,
    AppTextTheme text,
    AppLocalizations l10n,
    EncryptedSendState send,
    bool running,
  ) {
    if (running) {
      final canceling = send.phase == EncryptedSendPhase.canceling;
      return ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _overallProgress(send),
                backgroundColor: colors.borderButton,
                valueColor: AlwaysStoppedAnimation(colors.accentOrange),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              canceling ? l10n.commonCanceling : l10n.encryptedSendProgressFooter,
              textAlign: TextAlign.center,
              style: text.smallParagraph?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: 32),
            QuantusButton.simple(
              label: l10n.redeemCancel,
              variant: ButtonVariant.secondary,
              onTap: () => unawaited(ref.read(encryptedSendControllerProvider.notifier).cancel()),
              isDisabled: canceling,
            ),
          ],
        ),
      );
    }
    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(label: l10n.redeemClose, onTap: _goHome),
    );
  }
}
