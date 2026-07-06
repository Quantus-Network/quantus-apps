import 'dart:io';

import 'package:flutter/material.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_miner/src/services/miner_settings_service.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final _log = log.withTag('ClaimDialog');

Future<void> showClaimRewardsDialog({required BuildContext context, required BigInt balance}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ClaimRewardsDialog(balance: balance),
  );
}

class _ClaimRewardsDialog extends StatefulWidget {
  final BigInt balance;
  const _ClaimRewardsDialog({required this.balance});

  @override
  State<_ClaimRewardsDialog> createState() => _ClaimRewardsDialogState();
}

enum _Screen { input, confirm, progress }

class _ClaimRewardsDialogState extends State<_ClaimRewardsDialog> {
  final _addressController = TextEditingController();
  final _claimService = WormholeSendService();
  final _walletService = MinerWalletService();
  final _settingsService = MinerSettingsService();

  _Screen _screen = _Screen.input;
  String? _addressError;
  bool _running = false;
  bool _done = false;
  bool _cancelledTerminal = false;
  String? _errorMessage;
  int _currentStep = 0;
  final Map<int, ClaimProgressItem> _stepProgress = {};
  String? _resultMessage;

  static final _balanceFormatter = NumberFormattingService();

  @override
  void initState() {
    super.initState();
    _prefillDefaultAddress();
  }

  Future<void> _prefillDefaultAddress() async {
    try {
      final address = await _walletService.getDefaultAccountAddress();
      if (!mounted || address == null || _addressController.text.isNotEmpty) return;
      setState(() => _addressController.text = address);
    } catch (e) {
      _log.e('Failed to derive default destination address', error: e);
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  String _formatBalance(BigInt planck) =>
      _balanceFormatter.formatBalance(planck, smartDecimals: 4, addThousandsSeparators: false);

  bool _validateAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      setState(() => _addressError = 'Please enter a destination address');
      return false;
    }
    try {
      getAccountId32(trimmed);
    } catch (e) {
      setState(() => _addressError = 'Invalid address format');
      return false;
    }
    setState(() => _addressError = null);
    return true;
  }

  void _goToConfirm() {
    if (!_validateAddress(_addressController.text)) return;
    setState(() => _screen = _Screen.confirm);
  }

  void _goBack() {
    setState(() {
      _screen = _Screen.input;
      _addressError = null;
    });
  }

  Future<void> _startClaim() async {
    setState(() {
      _screen = _Screen.progress;
      _running = true;
      _done = false;
      _cancelledTerminal = false;
      _errorMessage = null;
      _currentStep = 0;
      _stepProgress.clear();
      _resultMessage = null;
    });

    try {
      final keyPair = await _walletService.getWormholeKeyPair();
      if (keyPair == null || keyPair.secretHex.isEmpty) {
        throw StateError('Wormhole key pair not available');
      }

      final chainConfig = await _settingsService.getChainConfig();
      final binsDir = '${await BinaryManager.getQuantusHomeDirectoryPath()}/generated-bins';
      await Directory(binsDir).create(recursive: true);

      final rpcUrl = chainConfig.rpcUrl;
      _log.i('Starting claim for ${keyPair.address} to ${_addressController.text.trim()}');

      final result = await _claimService.claimRewards(
        wormholeAddress: keyPair.address,
        secretHex: keyPair.secretHex,
        destinationAddress: _addressController.text.trim(),
        rpcUrl: rpcUrl,
        circuitBinsDir: binsDir,
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
        _resultMessage = '${result.transfersProcessed} transfers claimed in ${result.batchesSubmitted} batch(es)';
      });
    } on ClaimCancelled {
      if (!mounted) return;
      setState(() {
        _running = false;
        _cancelledTerminal = true;
        _resultMessage = 'Cancelled by user';
      });
    } catch (e) {
      _log.e('Claim failed', error: e);
      if (!mounted) return;
      setState(() {
        _running = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _cancelClaim() {
    _claimService.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(
        width: 540,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: switch (_screen) {
            _Screen.input => _buildInputScreen(),
            _Screen.confirm => _buildConfirmScreen(),
            _Screen.progress => _buildProgressScreen(),
          },
        ),
      ),
    );
  }

  Widget _buildInputScreen() {
    return Padding(
      key: const ValueKey('input'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Claim Rewards',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Claimable Balance', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.7))),
                Text(
                  '${_formatBalance(widget.balance)} QUAN',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF10B981),
                    fontFamily: 'Fira Code',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Destination Address', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
          const SizedBox(height: 8),
          TextField(
            controller: _addressController,
            style: const TextStyle(color: Colors.white, fontFamily: 'Fira Code', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Enter a Quantus address...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              errorText: _addressError,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF10B981)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _goToConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Claim All Rewards', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmScreen() {
    return Padding(
      key: const ValueKey('confirm'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_outlined, color: Colors.amber.shade300, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Confirm Withdrawal',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _confirmRow('Amount', '${_formatBalance(widget.balance)} QUAN'),
          const SizedBox(height: 12),
          _confirmRow('Destination', _addressController.text.trim(), mono: true),
          const SizedBox(height: 12),
          _confirmRow('Fee', '0.1% volume fee'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade300, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ZK proof generation may take several minutes. Do not close the app.',
                    style: TextStyle(fontSize: 12, color: Colors.amber.shade200),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _goBack,
                child: Text('Back', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _startClaim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool mono = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.5))),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.white, fontFamily: mono ? 'Fira Code' : null),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressScreen() {
    return Padding(
      key: const ValueKey('progress'),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_running)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                )
              else if (_errorMessage != null)
                const Icon(Icons.error_outline, color: Colors.red, size: 20)
              else if (_cancelledTerminal)
                Icon(Icons.cancel_outlined, color: Colors.white.withValues(alpha: 0.6), size: 20)
              else
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 12),
              Text(
                _running
                    ? 'Claiming Rewards...'
                    : _errorMessage != null
                    ? 'Claim Failed'
                    : _cancelledTerminal
                    ? 'Claim Cancelled'
                    : 'Claim Complete',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _buildStepRow(1, 'Preparing circuits'),
                _buildStepConnector(1),
                _buildStepRow(2, 'Fetching transfers'),
                _buildStepConnector(2),
                _buildStepRow(3, 'Computing nullifiers'),
                _buildStepConnector(3),
                _buildStepRow(4, 'Checking nullifiers'),
                _buildStepConnector(4),
                _buildStepRow(5, 'Generating ZK proofs'),
                _buildStepConnector(5),
                _buildStepRow(6, 'Aggregating proofs and submitting to chain'),
              ],
            ),
          ),
          if ((_done && _resultMessage != null) || _cancelledTerminal || _errorMessage != null) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (_) {
                final Color bannerColor = _errorMessage != null
                    ? Colors.red
                    : _cancelledTerminal
                    ? Colors.white
                    : const Color(0xFF10B981);
                final IconData bannerIcon = _errorMessage != null
                    ? Icons.error_outline
                    : _cancelledTerminal
                    ? Icons.info_outline
                    : Icons.check_circle_outline;
                final Color bannerTextColor = _errorMessage != null
                    ? Colors.red.shade300
                    : Colors.white.withValues(alpha: 0.9);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: bannerColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(bannerIcon, color: bannerColor, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage ?? _resultMessage ?? '',
                          style: TextStyle(fontSize: 13, color: bannerTextColor),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_running)
                TextButton(
                  onPressed: _cancelClaim,
                  child: const Text('Cancel', style: TextStyle(color: Colors.red)),
                )
              else ...[
                if (_errorMessage != null)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _screen = _Screen.confirm;
                        _errorMessage = null;
                      });
                    },
                    child: const Text('Retry', style: TextStyle(color: Color(0xFF10B981))),
                  ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _done && _errorMessage == null
                        ? const Color(0xFF10B981)
                        : Colors.white.withValues(alpha: 0.1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // Cancellation is a neutral terminal state: only the steps the flow actually
  // finished should be marked green. Done-without-cancel = fully complete →
  // every step is green. Steps with a known total (proof generation and batch
  // submission interleave per batch) complete by count, not step order.
  bool _isStepCompleted(int step) {
    if (_done) return true;
    final progress = _stepProgress[step];
    if (progress?.total != null) return progress!.completed >= progress.total!;
    return _currentStep > step;
  }

  Widget _buildStepRow(int step, String title) {
    final progress = _stepProgress[step];
    final isCompleted = _isStepCompleted(step);
    final isActive =
        !_done &&
        !_cancelledTerminal &&
        !isCompleted &&
        _errorMessage == null &&
        (_currentStep == step || (progress?.completed ?? 0) > 0);
    final isError = !_done && _currentStep == step && _errorMessage != null;

    Widget icon;
    if (isCompleted) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (isError) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red, width: 2),
        ),
        child: const Icon(Icons.close, color: Colors.red, size: 14),
      );
    } else if (isActive) {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF10B981), width: 2),
        ),
        child: const Padding(
          padding: EdgeInsets.all(5),
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
        ),
      );
    } else {
      icon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
        ),
        child: Center(
          child: Text(
            '$step',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    String progressText = '';
    if (progress != null && (progress.completed > 0 || isCompleted)) {
      if (step == 2) {
        progressText = '${progress.completed} fetched';
      } else if (progress.total != null) {
        progressText = '${progress.completed} / ${progress.total}';
      }
    }

    final titleColor = isCompleted
        ? const Color(0xFF10B981)
        : isActive
        ? Colors.white
        : isError
        ? Colors.red.shade300
        : Colors.white.withValues(alpha: 0.28);

    final progressColor = isCompleted
        ? const Color(0xFF10B981).withValues(alpha: 0.7)
        : isActive
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.3);

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
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: titleColor, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            if (progressText.isNotEmpty)
              Text(
                progressText,
                style: TextStyle(
                  color: progressColor,
                  fontSize: 13,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        if (progressFraction != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progressFraction,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepConnector(int afterStep) {
    final isCompleted = _isStepCompleted(afterStep);
    return Padding(
      padding: const EdgeInsets.only(left: 13),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 2,
          height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? const Color(0xFF10B981).withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
