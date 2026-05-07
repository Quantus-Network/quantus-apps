import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import 'claim_rewards_dialog.dart';

class WithdrawalScreen extends StatefulWidget {
  final String? wormholeAddress;

  const WithdrawalScreen({super.key, this.wormholeAddress});

  @override
  State<WithdrawalScreen> createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final _walletService = MinerWalletService();
  final _utxoService = WormholeUtxoService();
  BigInt? _balance;
  bool _loading = true;
  bool _canWithdraw = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final keyPair = await _walletService.getWormholeKeyPair();
    final canWithdraw = await _walletService.canWithdraw();
    BigInt? balance;
    if (keyPair != null && keyPair.secretHex.isNotEmpty) {
      try {
        balance = await _utxoService.getUnspentBalance(wormholeAddress: keyPair.address, secretHex: keyPair.secretHex);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _balance = balance;
      _canWithdraw = canWithdraw;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.wormholeAddress;
    final hasBalance = _balance != null && _balance! > BigInt.zero;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Withdraw Rewards'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (address != null) ...[
                Text('Rewards Address', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          address,
                          style: const TextStyle(fontFamily: 'Fira Code', fontSize: 12, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.7), size: 18),
                        onPressed: () => context.copyTextWithSnackbar(address),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                ElevatedButton.icon(
                  onPressed: _canWithdraw && hasBalance
                      ? () => showClaimRewardsDialog(context: context, balance: _balance!)
                      : null,
                  icon: const Icon(Icons.account_balance_wallet),
                  label: Text(
                    !_canWithdraw
                        ? 'Mnemonic required to claim'
                        : !hasBalance
                        ? 'No rewards to claim'
                        : 'Claim Rewards',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.05),
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
