import 'package:flutter/material.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

import '../withdrawal/claim_rewards_dialog.dart';

final _log = log.withTag('BalanceCard');

class MinerBalanceCard extends StatefulWidget {
  const MinerBalanceCard({super.key});

  @override
  State<MinerBalanceCard> createState() => _MinerBalanceCardState();
}

class _MinerBalanceCardState extends State<MinerBalanceCard> {
  final _walletService = MinerWalletService();
  final _utxoService = WormholeUtxoService();
  String? _address;
  BigInt? _balance;
  bool _loading = true;
  bool _balanceLoading = false;
  bool _canWithdraw = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String? _secretHex;

  Future<void> _loadData() async {
    _log.i('Loading wormhole key pair...');
    final keyPair = await _walletService.getWormholeKeyPair();
    final canWithdraw = await _walletService.canWithdraw();
    _log.i(
      'Key pair loaded: address=${keyPair?.address}, canWithdraw=$canWithdraw, hasSecret=${keyPair?.secretHex.isNotEmpty}',
    );
    if (!mounted) return;
    setState(() {
      _address = keyPair?.address;
      _secretHex = keyPair?.secretHex;
      _canWithdraw = canWithdraw;
      _loading = false;
    });

    if (keyPair != null && keyPair.secretHex.isNotEmpty) {
      _loadBalance(keyPair.address, keyPair.secretHex);
    } else {
      _log.w('No secret available — balance fetch skipped');
    }
  }

  static final _formatter = NumberFormattingService();

  Future<void> _loadBalance(String address, String secretHex) async {
    if (!mounted) return;
    setState(() => _balanceLoading = true);
    _log.i('Fetching unspent balance for $address ...');
    try {
      final balance = await _utxoService.getUnspentBalance(wormholeAddress: address, secretHex: secretHex);
      _log.i('Unspent balance: $balance planck (${_formatter.formatBalance(balance, addSymbol: true)})');
      if (!mounted) return;
      setState(() {
        _balance = balance;
        _balanceLoading = false;
      });
    } catch (e, st) {
      _log.e('Failed to load balance', error: e);
      _log.e('Stack trace: $st');
      if (!mounted) return;
      setState(() => _balanceLoading = false);
    }
  }

  void _refresh() {
    final address = _address;
    final secret = _secretHex;
    if (address != null && secret != null && secret.isNotEmpty) {
      _log.i('Manual refresh triggered');
      _loadBalance(address, secret);
    }
  }

  void _onClaimTap() {
    showClaimRewardsDialog(context: context, balance: _balance ?? BigInt.zero);
  }

  @override
  Widget build(BuildContext context) {
    final address = _address;
    final notConfigured = !_loading && address == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.savings, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rewards',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                if (!_loading && address != null) ...[
                  _buildBalanceDisplay(),
                  const SizedBox(width: 4),
                  _buildRefreshButton(),
                ],
              ],
            ),
            const SizedBox(height: 20),
            if (_loading)
              const SizedBox(height: 32, child: Center(child: CircularProgressIndicator()))
            else if (address != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, color: Colors.white.withValues(alpha: 0.5), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontFamily: 'Fira Code',
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.5), size: 16),
                      onPressed: () => context.copyTextWithSnackbar(address),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildClaimButton(),
            ] else if (notConfigured) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber.shade300, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rewards address not configured — complete the inner-hash setup first.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: _balanceLoading ? null : _refresh,
      icon: Icon(Icons.refresh, color: Colors.white.withValues(alpha: 0.5), size: 18),
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
      tooltip: 'Refresh balance',
    );
  }

  Widget _buildBalanceDisplay() {
    if (_balanceLoading) {
      return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    final bal = _balance;
    if (bal == null) return const SizedBox.shrink();

    return Text(
      _formatter.formatBalance(bal, maxDecimals: 2, addSymbol: true),
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: bal > BigInt.zero ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.5),
        fontFamily: 'Fira Code',
      ),
    );
  }

  Widget _buildClaimButton() {
    final hasBalance = _balance != null && _balance! > BigInt.zero;
    final enabled = _canWithdraw && hasBalance && !_balanceLoading;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? _onClaimTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            gradient: enabled ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]) : null,
            color: enabled ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.account_balance_wallet,
                color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                !_canWithdraw
                    ? 'Mnemonic required to claim'
                    : !hasBalance
                    ? 'No rewards to claim'
                    : 'Claim All Rewards',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
