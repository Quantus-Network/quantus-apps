import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/root_gate.dart';
import 'package:quantus_cold_wallet/components/connectivity_guard.dart';
import 'package:quantus_cold_wallet/components/lock_overlay.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

class ColdWalletApp extends ConsumerStatefulWidget {
  const ColdWalletApp({super.key});

  @override
  ConsumerState<ColdWalletApp> createState() => _ColdWalletAppState();
}

class _ColdWalletAppState extends ConsumerState<ColdWalletApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-lock whenever the app leaves the foreground so the mnemonic never
    // sits unlocked in the background.
    if (state == AppLifecycleState.paused) {
      ref.read(walletControllerProvider.notifier).lockOnBackground();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantus Cold Wallet',
      debugShowCheckedModeBanner: false,
      theme: coldTheme(context),
      darkTheme: coldTheme(context),
      themeMode: ThemeMode.dark,
      home: const RootGate(),
      builder: (context, child) => Stack(children: [?child, const LockOverlay(), const ConnectivityGuard()]),
    );
  }
}
