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

  Future<void> _showCliWithdrawalDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.terminal, color: Colors.blue.shade300, size: 24),
            const SizedBox(width: 12),
            const Text('Claim rewards via CLI', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _CliStep(
                  number: 1,
                  title: 'Download quantus-cli',
                  description: 'Get the latest archive from GitHub Releases:',
                  command: 'https://github.com/Quantus-Network/quantus-cli/releases/latest',
                ),
                SizedBox(height: 16),
                _CliStep(
                  number: 2,
                  title: 'Extract and make executable',
                  description: 'On macOS, also clear the quarantine flag:',
                  command:
                      'tar -xzf quantus-cli-*.tar.gz --strip-components=1\n'
                      'chmod +x quantus\n'
                      'xattr -d com.apple.quarantine quantus\n'
                      './quantus --version',
                ),
                SizedBox(height: 16),
                _CliStep(
                  number: 3,
                  title: 'Import your secret phrase',
                  description: 'Use the same recovery words you set up in the miner app:',
                  command: './quantus wallet import --name mining --mnemonic "YOUR SECRET WORDS"',
                ),
                SizedBox(height: 16),
                _CliStep(
                  number: 4,
                  title: 'Collect mined tokens',
                  description: 'Sweeps all wormhole rewards into the mining wallet:',
                  command:
                      './quantus \\\n'
                      '  --node-url wss://a1-planck.quantus.cat \\\n'
                      '  --verbose --wait-for-transaction \\\n'
                      '  wormhole collect-rewards --wallet mining',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
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
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _showCliWithdrawalDialog,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
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
                            'In-app withdrawals coming soon. Tap to claim rewards via CLI.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade200),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Colors.blue.shade300, size: 16),
                      ],
                    ),
                  ),
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

class _CliStep extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  final String command;

  const _CliStep({required this.number, required this.title, required this.description, required this.command});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Text(
                '$number',
                style: TextStyle(color: Colors.blue.shade200, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 34),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    command,
                    style: const TextStyle(color: Color(0xFF7CE38B), fontFamily: 'Courier', fontSize: 12, height: 1.45),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.5), size: 16),
                  tooltip: 'Copy',
                  onPressed: () => context.copyTextWithSnackbar(command, message: 'Copied to clipboard'),
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(6),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
