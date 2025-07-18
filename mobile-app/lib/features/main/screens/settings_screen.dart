import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/reset_confirmation_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/authentication_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/show_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  void _resetAndClearData() {
    _settingsService.clearAll();
    _logout();
  }

  Future<void> _logout() async {
    try {
      await SubstrateService().logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Logout failed: ${e.toString()}',
          icon: buildErrorIcon(),
        );
      }
    }
  }

  void _showResetConfirmationSheet() {
    showAppModalBottomSheet(
      context: context,
      builder: (context) {
        return ResetConfirmationBottomSheet(onReset: _resetAndClearData);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const WalletAppBar(title: 'Wallet Settings'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  children: [
                    const SizedBox(height: 22),
                    _buildSettingsList(context),
                    const SizedBox(height: 35),
                    _buildInformationList(context),
                    const SizedBox(height: 35),
                    _buildResetButton(context),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, bottom: 22.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFE6E6E6),
          fontSize: 16,
          fontFamily: 'Fira Code',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Wallet Settings'),
        _buildSettingsItem(context, 'Manage Accounts', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AccountsScreen()),
          );
        }),
        const SizedBox(height: 22),
        _buildSettingsItem(context, 'Notifications', () {}),
        const SizedBox(height: 22),
        _buildSettingsItem(context, 'Authentication', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AuthenticationSettingsScreen(),
            ),
          );
        }),
        const SizedBox(height: 22),
        _buildSettingsItem(context, 'Show Recovery Phrase', () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ShowRecoveryPhraseScreen(),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildInformationList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Information'),
        _buildSettingsItem(context, 'Help & Support', () {}, showArrow: false),
        const SizedBox(height: 22),
        _buildSettingsItem(
          context,
          'Invite & Share',
          () {},
          trailing: const Icon(Icons.share, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 22),
        _buildSettingsItem(context, 'Term of Service', () {}, showArrow: false),
      ],
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    String title,
    VoidCallback onTap, {
    Widget? trailing,
    bool showArrow = true,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
          top: 12,
          left: 18,
          right: 18,
          bottom: 12,
        ),
        decoration: ShapeDecoration(
          color: const Color(0xFF313131),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            trailing ??
                (showArrow
                    ? const Icon(
                        Icons.arrow_forward_ios,
                        size: 11,
                        color: Colors.white70,
                      )
                    : const SizedBox()),
          ],
        ),
      ),
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return GestureDetector(
      onTap: _showResetConfirmationSheet,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
          top: 12,
          left: 18,
          right: 18,
          bottom: 12,
        ),
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0xFFFF2D53)),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Reset & Clear Data',
              style: TextStyle(
                color: Color(0xFFFF2D53),
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 11, color: Color(0xFFFF2D53)),
          ],
        ),
      ),
    );
  }
}
