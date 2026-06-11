import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/root_gate.dart';
import 'package:quantus_cold_wallet/theme/app_theme.dart';
import 'package:quantus_cold_wallet/widgets/connectivity_guard.dart';
import 'package:quantus_cold_wallet/widgets/lock_overlay.dart';

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
      ref.read(walletControllerProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantus Cold Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme(context),
      darkTheme: AppTheme.darkTheme(context),
      themeMode: ThemeMode.dark,
      home: const RootGate(),
      builder: (context, child) => Stack(children: [?child, const LockOverlay(), const ConnectivityGuard()]),
    );
  }
}
