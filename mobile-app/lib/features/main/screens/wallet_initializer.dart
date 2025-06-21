import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class WalletInitializer extends StatefulWidget {
  const WalletInitializer({super.key});

  @override
  WalletInitializerState createState() => WalletInitializerState();
}

class WalletInitializerState extends State<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;
  final SettingsService _settingsService = ServiceLocator().settingsService;

  @override
  void initState() {
    super.initState();
    _checkWalletExists();
  }

  Future<void> _checkWalletExists() async {
    final hasWallet = await _settingsService.getHasWallet();

    setState(() {
      _walletExists = hasWallet;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_walletExists) {
      return const WalletMain();
    } else {
      return const WelcomeScreen();
    }
  }
}
