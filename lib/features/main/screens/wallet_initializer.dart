import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance_network_wallet/main.dart';

class WalletInitializer extends StatefulWidget {
  const WalletInitializer({super.key});

  @override
  WalletInitializerState createState() => WalletInitializerState();
}

class WalletInitializerState extends State<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;

  @override
  void initState() {
    super.initState();
    _checkWalletExists();
  }

  Future<void> _checkWalletExists() async {
    final prefs = await SharedPreferences.getInstance();
    final hasWallet = prefs.getBool('has_wallet') ?? false;

    setState(() {
      _walletExists = hasWallet;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_walletExists) {
      return const WalletMain();
    } else {
      return const WelcomeScreen();
    }
  }
}
