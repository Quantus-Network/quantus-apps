import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/wormhole_progress_steps.dart';

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
        // A cancel that landed after some batches were submitted comes back
        // as a partial result — show it as cancelled, with the real totals.
        _done = !result.cancelled;
        _cancelled = result.cancelled;
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
      quantusPrint('[Redeem] Claim failed: $e');
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
        mainContent: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              _buildStatusHeader(colors, text, l10n),
              const SizedBox(height: 32),
              _buildSteps(l10n),
              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                QuantusBanner(tone: BannerTone.ember, message: _errorMessage!),
              ],
              if (_done && _result != null) ...[const SizedBox(height: 24), _buildSuccessBanner(l10n)],
            ],
          ),
        ),
        bottomContent: _buildBottomContent(l10n),
      ),
    );
  }

  Widget _buildStatusHeader(AppColorsV3 colors, AppTextThemeV3 text, AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final amountLabel = fmt.formatBalance(widget.redeemableRewards, maxDecimals: 2, addSymbol: true);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.redeemingLabel, style: text.labelData.copyWith(color: colors.textMuted)),
          Text(amountLabel, style: text.amountInline.copyWith(color: colors.semanticSage)),
        ],
      ),
    );
  }

  Widget _buildSteps(AppLocalizations l10n) {
    return WormholeProgressSteps(
      steps: [
        (1, l10n.redeemStepCircuits),
        (2, l10n.redeemStepTransfers),
        (3, l10n.redeemStepNullifiers),
        (4, l10n.redeemStepProofs),
        (5, l10n.redeemStepAggregate),
        (6, l10n.redeemStepSubmit),
      ],
      stepProgress: _stepProgress,
      currentStep: _currentStep,
      done: _done,
      cancelled: _cancelled,
      hasError: _errorMessage != null,
      progressLabelOverride: (step, progress) => step == 2 ? l10n.redeemFetchedCount(progress.completed) : null,
    );
  }

  Widget _buildSuccessBanner(AppLocalizations l10n) {
    final fmt = ref.watch(numberFormattingServiceProvider);
    final withdrawn = fmt.formatBalance(_result!.totalWithdrawn, maxDecimals: 4, addSymbol: true);
    return QuantusBanner(
      tone: BannerTone.sage,
      message: l10n.redeemSuccessBanner(withdrawn, _result!.batchesSubmitted),
    );
  }

  Widget? _buildBottomContent(AppLocalizations l10n) {
    if (_running) {
      return ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: l10n.redeemCancel, variant: ButtonVariant.staged, onTap: _cancel),
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
                variant: ButtonVariant.staged,
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
