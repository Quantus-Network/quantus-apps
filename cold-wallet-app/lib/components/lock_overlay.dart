import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';

/// Shows the lock screen as a full-screen overlay whenever the wallet is
/// locked, so it covers any pushed route (Show Key, Sign) — not just the home
/// route — after the app is backgrounded.
///
/// This sits above the [Navigator] in [MaterialApp.builder], so the lock UI
/// must provide its own [Overlay] for [TextField] selection handles.
class LockOverlay extends ConsumerWidget {
  const LockOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(walletControllerProvider.select((s) => s.status));
    if (status != WalletStatus.locked) return const SizedBox.shrink();
    return Positioned.fill(child: Overlay.wrap(child: const LockScreen()));
  }
}
