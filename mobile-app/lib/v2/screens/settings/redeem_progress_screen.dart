import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
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
  WormholeClaimService? _claimService;
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
      _claimService = WormholeClaimService();

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

    return PopScope(
      canPop: !_running,
      child: ScaffoldBase(
        appBar: V2AppBar(
          title: _done ? 'Redeem Complete' : _errorMessage != null ? 'Redeem Failed' : 'Redeeming...',
          showBackButton: !_running,
        ),
        mainContent: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            _buildStatusHeader(colors, text),
            const SizedBox(height: 32),
            _buildSteps(colors, text),
            if (_errorMessage != null) ...[
              const SizedBox(height: 24),
              _buildErrorBanner(colors, text),
            ],
            if (_done && _result != null) ...[
              const SizedBox(height: 24),
              _buildSuccessBanner(colors, text),
            ],
          ],
        ),
        bottomContent: _buildBottomContent(colors),
      ),
    );
  }

  Widget _buildStatusHeader(AppColorsV2 colors, AppTextTheme text) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountLabel = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.sheetBackground, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('REDEEMING', style: text.receiveLabel?.copyWith(color: colors.textLabel)),
          Text(amountLabel, style: text.sendSectionLabel?.copyWith(color: colors.success)),
        ],
      ),
    );
  }

  Widget _buildSteps(AppColorsV2 colors, AppTextTheme text) {
    const steps = [
      (1, 'Preparing circuits'),
      (2, 'Fetching transfers'),
      (3, 'Computing nullifiers'),
      (4, 'Checking nullifiers'),
      (5, 'Generating ZK proofs'),
      (6, 'Submitting to chain'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            _buildStepRow(steps[i].$1, steps[i].$2, colors, text),
            if (i < steps.length - 1) _buildConnector(steps[i].$1, colors),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(int step, String title, AppColorsV2 colors, AppTextTheme text) {
    final isCompleted = _done ? true : _currentStep > step;
    final isActive = !_done && !_cancelled && _currentStep == step && _errorMessage == null;
    final isError = !_done && _currentStep == step && _errorMessage != null;
    final progress = _stepProgress[step];

    final Widget icon;
    if (isCompleted) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: colors.success, shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (isError) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.textError.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: colors.textError, width: 2),
        ),
        child: Icon(Icons.close, color: colors.textError, size: 14),
      );
    } else if (isActive) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: colors.success.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: colors.success, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2, color: colors.success),
        ),
      );
    } else {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.borderButton.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Center(
          child: Text('$step', style: text.detail?.copyWith(color: colors.textTertiary)),
        ),
      );
    }

    final titleColor = isCompleted
        ? colors.success
        : isActive
            ? colors.textPrimary
            : isError
                ? colors.textError
                : colors.textTertiary;

    String progressText = '';
    if (progress != null && progress.completed > 0) {
      if (step == 2) {
        progressText = '${progress.completed} fetched';
      } else if (progress.total != null) {
        progressText = '${progress.completed} / ${progress.total}';
      }
    }

    double? progressFraction;
    if (isActive && progress != null && progress.total != null && progress.total! > 0) {
      progressFraction = (progress.completed / progress.total!).clamp(0.0, 1.0);
    }

    return Column(
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: text.smallParagraph?.copyWith(color: titleColor))),
            if (progressText.isNotEmpty)
              Text(progressText, style: text.detail?.copyWith(
                color: isCompleted ? colors.success : colors.textPrimary,
                fontFamily: AppTextTheme.fontFamilySecondary,
              )),
          ],
        ),
        if (progressFraction != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: colors.borderButton.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(colors.success),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnector(int afterStep, AppColorsV2 colors) {
    final isCompleted = _done ? true : _currentStep > afterStep;
    return Padding(
      padding: const EdgeInsets.only(left: 13),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted ? colors.success.withValues(alpha: 0.4) : colors.borderButton.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
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
          Expanded(child: Text(_errorMessage!, style: text.detail?.copyWith(color: colors.textError))),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(AppColorsV2 colors, AppTextTheme text) {
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
              '$withdrawn redeemed in ${_result!.batchesSubmitted} batch(es)',
              style: text.detail?.copyWith(color: colors.success),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomContent(AppColorsV2 colors) {
    if (_running) {
      return ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Cancel',
          variant: ButtonVariant.secondary,
          onTap: _cancel,
        ),
      );
    }

    if (_errorMessage != null) {
      return ScaffoldBaseBottomContent(
        child: Row(
          children: [
            Expanded(
              child: QuantusButton.simple(label: 'Retry', onTap: _retry),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuantusButton.simple(
                label: 'Close',
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
        label: 'Done',
        onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
      ),
    );
  }
}
