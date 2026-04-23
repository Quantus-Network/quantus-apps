import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';

/// Placeholder withdrawal screen.
///
/// The original in-app flow depended on a ZK proof SDK + nullifier Rust FFI
/// that is being rebuilt. Until that lands, we direct users to the CLI.
class WithdrawalScreen extends StatelessWidget {
  final String? wormholeAddress;

  const WithdrawalScreen({super.key, this.wormholeAddress});

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.construction, color: Colors.blue.shade300),
                        const SizedBox(width: 12),
                        const Text(
                          'Withdrawals coming soon',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'In-app ZK withdrawals are being rebuilt. For now, claim rewards from the CLI '
                      'using your wormhole secret.',
                      style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              if (wormholeAddress != null) ...[
                const SizedBox(height: 24),
                Text(
                  'Rewards Address',
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
                ),
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
                          wormholeAddress!,
                          style: const TextStyle(fontFamily: 'Fira Code', fontSize: 12, color: Colors.white),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.copy, color: Colors.white.withValues(alpha: 0.7), size: 18),
                        onPressed: () => context.copyTextWithSnackbar(wormholeAddress!),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
