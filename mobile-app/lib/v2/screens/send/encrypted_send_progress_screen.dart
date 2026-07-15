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
  bool _canceling = false;
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SendTerminalScreen(content: widget.terminal)),
      );
    } on ClaimCancelled {
      ref.invalidate(encryptedStateProvider(widget.account.walletIndex));
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

  Future<void> _cancel() async {
    if (_canceling) return;
    setState(() => _canceling = true);
    await ref.read(encryptedAccountServiceProvider(widget.account.walletIndex)).cancel();
    if (!mounted) return;
    setState(() {
      _running = false;
      _cancelled = true;
    });
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
              stepProgress: _stepProgress,
              currentStep: _currentStep,
              done: false,
              cancelled: _cancelled,
              hasError: _errorMessage != null,
            ),
            if (_errorMessage != null) ...[const SizedBox(height: 24), _buildErrorBanner(colors, text)],
          ],
        ),
        bottomContent: _buildBottomContent(colors, l10n),
      ),
    );
  }

  Widget _buildStatusHeader(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountLabel = fmt.formatBalance(widget.plan.amountPlanck, maxDecimals: 2, addSymbol: true);
    final shortAddr = AddressFormattingService.formatAddress(widget.recipientAddress.trim());

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.encryptedSendingLabel,
            style: TextStyle(
              fontFamily: AppTextTheme.fontFamilySecondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: const Color(0xFF787878),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            amountLabel,
            style: TextStyle(
              fontFamily: AppTextTheme.fontFamilySecondary,
              fontSize: 32,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (widget.terminal.recipientChecksum != null) ...[
            Text(
              widget.terminal.recipientChecksum!,
              style: TextStyle(fontSize: 12, color: colors.checksum),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            shortAddr,
            style: TextStyle(
              fontFamily: AppTextTheme.fontFamilySecondary,
              fontSize: 12,
              color: const Color(0xFF8C8C8C),
            ),
          ),
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

  double get _overallProgress {
    const displaySteps = [1, 4, 5, 6];
    int completed = 0;
    for (final id in displaySteps) {
      final p = _stepProgress[id];
      if (p != null && p.total != null && p.completed >= p.total!) {
        completed++;
      } else if (p != null && _currentStep > id) {
        completed++;
      }
    }
    return (completed / displaySteps.length).clamp(0.0, 1.0);
  }

  Widget _buildBottomContent(AppColorsV2 colors, AppLocalizations l10n) {
    if (_running) {
      return ScaffoldBaseBottomContent(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: _overallProgress,
                backgroundColor: const Color(0xFF222222),
                valueColor: AlwaysStoppedAnimation(colors.accentOrange),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _canceling ? l10n.commonCanceling : l10n.encryptedSendProgressFooter,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF3D3D3D)),
            ),
            const SizedBox(height: 32),
            QuantusButton.simple(
              label: l10n.redeemCancel,
              variant: ButtonVariant.secondary,
              onTap: _cancel,
              isDisabled: _canceling,
            ),
          ],
        ),
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
