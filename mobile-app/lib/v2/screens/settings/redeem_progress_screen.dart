import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/components/wormhole_progress_steps.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class RedeemProgressScreen extends ConsumerStatefulWidget {
  final BigInt redeemableRewards;
  final String destinationAddress;

  const RedeemProgressScreen({super.key, required this.redeemableRewards, required this.destinationAddress});

  @override
  ConsumerState<RedeemProgressScreen> createState() => _RedeemProgressScreenState();
}

class _RedeemProgressScreenState extends ConsumerState<RedeemProgressScreen> {
  WormholeSendService? _claimService;
  bool _running = true;
  bool _done = false;
  bool _cancelled = false;
  String? _errorMessage;
  int _currentStep = 0;
  final Map<int, ClaimProgressItem> _stepProgress = {};
  ClaimResult? _result;

  @override
  void initState() {
    super.initState();
    _startClaim();
  }

  Future<void> _startClaim() async {
    try {
      final mnemonic = await ref.read(settingsServiceProvider).getMnemonic(0);
      if (mnemonic == null) throw StateError('Mnemonic not found');

      final keyPair = ref.read(hdWalletServiceProvider).deriveWormholeKeyPair(mnemonic: mnemonic);
      if (keyPair.secretHex.isEmpty) throw StateError('Wormhole key pair not available');

      final circuitDir = await CircuitManager.getCircuitDirectory();
      _claimService = WormholeSendService();

      final result = await _claimService!.claimRewards(
        wormholeAddress: keyPair.address,
        secretHex: keyPair.secretHex,
        destinationAddress: widget.destinationAddress,
        circuitBinsDir: circuitDir,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _currentStep = progress.step;
            _stepProgress[progress.step] = progress;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _done = true;
        _running = false;
        _result = result;
      });
      ref.invalidate(miningRewardsProvider);
    } on ClaimCancelled {
      if (!mounted) return;
      setState(() {
        _running = false;
        _cancelled = true;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[Redeem] Claim failed: $e');
      if (!mounted) return;
      setState(() {
        _running = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _cancel() {
    _claimService?.cancel();
  }

  void _retry() {
    setState(() {
      _running = true;
      _done = false;
      _cancelled = false;
      _errorMessage = null;
      _currentStep = 0;
      _stepProgress.clear();
      _result = null;
    });
    _startClaim();
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
          title: _done
              ? l10n.redeemCompleteTitle
              : _errorMessage != null
              ? l10n.redeemFailedTitle
              : l10n.redeemProgressTitle,
          showBackButton: !_running,
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _buildStatusHeader(colors, text, l10n),
            const SizedBox(height: 32),
            _buildSteps(colors, text, l10n),
            if (_errorMessage != null) ...[const SizedBox(height: 24), _buildErrorBanner(colors, text)],
            if (_done && _result != null) ...[const SizedBox(height: 24), _buildSuccessBanner(colors, text, l10n)],
          ],
        ),
        bottomContent: _buildBottomContent(colors, l10n),
      ),
    );
  }

  Widget _buildStatusHeader(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountLabel = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.redeemingLabel, style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          Text(amountLabel, style: text.sendSectionLabel?.copyWith(color: colors.success)),
        ],
      ),
    );
  }

  Widget _buildSteps(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    return WormholeProgressSteps(
      steps: [
        (1, l10n.redeemStepCircuits),
        (2, l10n.redeemStepTransfers),
        (3, l10n.redeemStepNullifiers),
        (4, l10n.redeemStepCheckNullifiers),
        (5, l10n.redeemStepProofs),
        (6, l10n.redeemStepAggregate),
      ],
      stepProgress: _stepProgress,
      currentStep: _currentStep,
      done: _done,
      cancelled: _cancelled,
      hasError: _errorMessage != null,
      progressLabelOverride: (step, progress) => step == 2 ? l10n.redeemFetchedCount(progress.completed) : null,
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

  Widget _buildSuccessBanner(AppColorsV2 colors, AppTextTheme text, AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final withdrawn = fmt.formatBalance(_result!.totalWithdrawn, maxDecimals: 4, addSymbol: true);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.success.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.success, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.redeemSuccessBanner(withdrawn, _result!.batchesSubmitted),
              style: text.detail?.copyWith(color: colors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomContent(AppColorsV2 colors, AppLocalizations l10n) {
    if (_running) {
      return ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: l10n.redeemCancel, variant: ButtonVariant.secondary, onTap: _cancel),
      );
    }

    if (_errorMessage != null) {
      return ScaffoldBaseBottomContent(
        child: Row(
          children: [
            Expanded(
              child: QuantusButton.simple(label: l10n.redeemRetry, onTap: _retry),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuantusButton.simple(
                label: l10n.redeemClose,
                variant: ButtonVariant.secondary,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    return ScaffoldBaseBottomContent(
      child: QuantusButton.simple(
        label: l10n.redeemDone,
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}
