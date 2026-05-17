import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/features/settings/settings_screen.dart';
import 'package:quantus_miner/main.dart';
import 'package:quantus_miner/src/services/miner_settings_service.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

enum _MenuValues { walletLogout, logout, setting }

class MinerAppBar extends StatefulWidget {
  const MinerAppBar({super.key});

  @override
  State<MinerAppBar> createState() => _MinerAppBarState();
}

class _MinerAppBarState extends State<MinerAppBar> {
  final _minerSettingsService = MinerSettingsService();
  final _walletService = MinerWalletService();

  Future<void> _performWalletLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout Wallet?'),
          content: const Text(
            'This will wipe your secret phrase and inner hash from this app so you can enter a different one. Your node and node identity are kept. Mining will be stopped.\n\nContinue?',
          ),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
            TextButton(
              child: const Text('Logout Wallet', style: TextStyle(color: Colors.orange)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final orchestrator = GlobalMinerManager.getOrchestrator();
    if (orchestrator?.isRunning == true) {
      await orchestrator!.stop();
    }
    await _walletService.deleteWalletData();
    if (mounted) {
      context.go('/rewards_address_setup');
    }
  }

  Future<void> _performLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout?'),
          content: const Text(
            'This will delete your stored inner hash, node identity, and the downloaded node binary. You will need to go through the full setup process again.\n\nAre you sure you want to continue?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _minerSettingsService.logout();
      if (mounted) {
        context.go('/node_setup');
      }
    }
  }

  void _goToSettingScreen() {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      floating: true,
      pinned: false,
      flexibleSpace: ClipRRect(
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
        child: BackdropFilter(
          filter: ColorFilter.mode(Colors.black.useOpacity(0.1), BlendMode.srcOver),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.useOpacity(0.1), Colors.white.useOpacity(0.05)],
              ),
              border: Border(bottom: BorderSide(color: Colors.white.useOpacity(0.1), width: 1)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Row(
                    children: [
                      SvgPicture.asset('assets/logo/logo.svg', height: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Quantus Miner',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.useOpacity(0.1),
                      border: Border.all(color: Colors.white.useOpacity(0.2), width: 1),
                    ),
                    child: PopupMenuButton<_MenuValues>(
                      color: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (_MenuValues item) async {
                        switch (item) {
                          case _MenuValues.walletLogout:
                            await _performWalletLogout();
                            break;
                          case _MenuValues.logout:
                            await _performLogout();
                            break;
                          case _MenuValues.setting:
                            _goToSettingScreen();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<_MenuValues>>[
                        PopupMenuItem<_MenuValues>(
                          value: _MenuValues.walletLogout,
                          child: Row(
                            children: [
                              Icon(Icons.key_off, color: Colors.orange.useOpacity(0.9), size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'Logout Wallet',
                                style: TextStyle(color: Colors.white.useOpacity(0.9), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<_MenuValues>(
                          value: _MenuValues.logout,
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red.useOpacity(0.8), size: 20),
                              const SizedBox(width: 12),
                              Text('Reset App', style: TextStyle(color: Colors.white.useOpacity(0.9), fontSize: 14)),
                            ],
                          ),
                        ),
                        PopupMenuItem<_MenuValues>(
                          value: _MenuValues.setting,
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Colors.grey.useOpacity(0.8), size: 20),
                              const SizedBox(width: 12),
                              Text('Settings', style: TextStyle(color: Colors.white.useOpacity(0.9), fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(Icons.menu, color: Colors.white.useOpacity(0.7), size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
