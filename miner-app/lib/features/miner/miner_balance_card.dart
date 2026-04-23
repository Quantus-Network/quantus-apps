import 'package:flutter/material.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';

/// Card displaying the configured rewards wormhole address.
///
/// Balance tracking + withdraw flow are gated on the new wormhole SDK work;
/// until that lands the card just surfaces the address so users can confirm
/// rewards are being directed correctly and withdraw via CLI.
class MinerBalanceCard extends StatefulWidget {
  const MinerBalanceCard({super.key});

  @override
  State<MinerBalanceCard> createState() => _MinerBalanceCardState();
}

class _MinerBalanceCardState extends State<MinerBalanceCard> {
  final _walletService = MinerWalletService();
  String? _address;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final address = await _walletService.getRewardsAddress();
    if (!mounted) return;
    setState(() {
      _address = address;
      _loading = false;
    });
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
                Text(
                  'Rewards Address',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2), width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade300, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'In-app withdrawals coming soon. Use the CLI to claim rewards in the meantime.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade200),
                      ),
                    ),
                  ],
                ),
              ),
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
}
