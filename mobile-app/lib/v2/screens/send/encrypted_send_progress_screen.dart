import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/components/wormhole_progress_steps.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_terminal_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Drives an encrypted send: proves the planned spends, submits the batches
/// and then replaces itself with the shared send terminal screen.
///
/// There is no retry here — after a partial submission the plan is stale
/// (some inputs are spent), so the user re-initiates from Home against the
/// refreshed UTXO set instead.
class EncryptedSendProgressScreen extends ConsumerStatefulWidget {
  final Account account;
  final WormholeSpendPlan plan;
  final String recipientAddress;
  final SendTerminalContent terminal;

  const EncryptedSendProgressScreen({
    super.key,
    required this.account,
    required this.plan,
    required this.recipientAddress,
    required this.terminal,
  });

  @override
  ConsumerState<EncryptedSendProgressScreen> createState() => _EncryptedSendProgressScreenState();
}

class _EncryptedSendProgressScreenState extends ConsumerState<EncryptedSendProgressScreen> {
  bool _running = true;
  bool _cancelled = false;
  String? _errorMessage;
  int _currentStep = 0;
  final Map<int, ClaimProgressItem> _stepProgress = {};

  @override
  void initState() {
    super.initState();
    _startSend();
  }

  Future<void> _startSend() async {
    final service = ref.read(encryptedAccountServiceProvider(widget.account.walletIndex));
    try {
      final circuitDir = await CircuitManager.getCircuitDirectory();
      await service.send(
        plan: widget.plan,
        recipientAddress: widget.recipientAddress,
        circuitBinsDir: circuitDir,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _currentStep = progress.step;
            _stepProgress[progress.step] = progress;
          });
        },
      );

      ref.invalidate(encryptedStateProvider(widget.account.walletIndex));
      unawaited(
        RecentAddressesService()
            .addAddress(widget.recipientAddress)
            .catchError((Object e) => debugPrint('Failed to save recent address: $e')),
      );
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SendTerminalScreen(content: widget.terminal)));
    } on ClaimCancelled {
      ref.invalidate(encryptedStateProvider(widget.account.walletIndex));
      if (!mounted) return;
      setState(() {
        _running = false;
        _cancelled = true;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[EncryptedSend] Send failed: $e');
      ref.invalidate(encryptedStateProvider(widget.account.walletIndex));
      if (!mounted) return;
      setState(() {
        _running = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _cancel() {
    ref.read(encryptedAccountServiceProvider(widget.account.walletIndex)).cancel();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final l10n = ref.watch(l10nProvider);

    return PopScope(
      canPop: !_running,
      child: ScaffoldBase(
        appBar: V2AppBar(
          title: _errorMessage != null
              ? l10n.encryptedSendFailedTitle
              : _cancelled
              ? l10n.encryptedSendCancelledTitle
              : l10n.encryptedSendProgressTitle,
          showBackButton: !_running,
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _buildStatusHeader(colors, text, l10n),
            const SizedBox(height: 32),
            WormholeProgressSteps(
              steps: [
                (1, l10n.redeemStepCircuits),
                (5, l10n.redeemStepProofs),
                (6, l10n.redeemStepAggregate),
              ],
              stepProgress: _stepProgress,
              currentStep: _currentStep,
              done: false,
              cancelled: _cancelled,
              hasError: _errorMessage != null,
            ),
            if (_errorMessage != null) ...[const SizedBox(height: 24), _buildErrorBanner(colors, text)],
          ],
        ),
        bottomContent: _buildBottomContent(l10n),
      ),
    );
  }

  Widget _buildStatusHeader(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountLabel = fmt.formatBalance(widget.plan.amountPlanck, maxDecimals: 2, addSymbol: true);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.encryptedSendingLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          Text(amountLabel, style: text.sendSectionLabel?.copyWith(color: colors.success)),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.textError.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textError.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colors.textError, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent(AppLocalizations l10n) {
    if (_running) {
      return ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: l10n.redeemCancel, variant: ButtonVariant.secondary, onTap: _cancel),
      );
    }
    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(
        label: l10n.redeemClose,
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}
