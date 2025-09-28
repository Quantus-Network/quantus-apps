import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class WalletInitializer extends StatefulWidget {
  final String? address;

  const WalletInitializer({super.key, this.address});

  @override
  WalletInitializerState createState() => WalletInitializerState();
}

class WalletInitializerState extends State<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;
  bool _needsMigration = false;
  List<MigrationAccountData>? _migrationData;
  final SettingsService _settingsService = SettingsService();
  late final MigrationService _migrationService;

  @override
  void initState() {
    super.initState();
    _migrationService = MigrationService(_settingsService, HdWalletService());
    _checkWalletAndMigration();
  }

  Future<void> _checkWalletAndMigration() async {
    final hasWallet = await _settingsService.getHasWallet();
    final needsMigration = _migrationService.needsMigration();

    if (needsMigration) {
      try {
        final migrationData = await _migrationService.getMigrationData();
        setState(() {
          _needsMigration = true;
          _migrationData = migrationData;
          _loading = false;
        });
      } catch (e) {
        // If migration data can't be loaded, continue without migration
        setState(() {
          _walletExists = hasWallet;
          _loading = false;
        });
      }
    } else {
      setState(() {
        _walletExists = hasWallet;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsMigration && _migrationData != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_walletExists) {
      return Navbar(address: widget.address);
    } else {
      return const WelcomeScreen();
    }
  }
}
