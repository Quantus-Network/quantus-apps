import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/reset_confirmation_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/authentication_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/show_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();

  void _resetAndClearData() {
    _settingsService.clearAll();
    _logout();
  }

  Future<void> _logout() async {
    try {
      print('settings screen logout');
      await SubstrateService().logout();
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      ref.read(pendingTransactionsProvider.notifier).clear();
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
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
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
        style: context.themeText.largeTag?.copyWith(
          color: context.themeColors.light,
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
        _buildSettingsItem(context, 'Help & Support', () {
          final Uri url = Uri.parse(AppConstants.helpAndSupportUrl);
          launchUrl(url);
        }, showArrow: false),
        const SizedBox(height: 22),
        _buildSettingsItem(
          context,
          'Invite & Share',
          () {},
          trailing: Icon(
            Icons.share,
            size: context.themeSize.settingMenuShareIconSize,
          ),
        ),
        const SizedBox(height: 22),
        _buildSettingsItem(context, 'Term of Service', () {
          final Uri url = Uri.parse(AppConstants.termsOfServiceUrl);
          launchUrl(url);
        }, showArrow: false),
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
        padding: EdgeInsets.symmetric(
          vertical: context.isTablet ? 16 : 12,
          horizontal: 18,
        ),
        decoration: ShapeDecoration(
          color: const Color(0xFF313131),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: context.themeText.smallParagraph),
            trailing ??
                (showArrow
                    ? Icon(
                        Icons.arrow_forward_ios,
                        size: context.themeSize.settingMenuIconSize,
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
        padding: EdgeInsets.symmetric(
          vertical: context.isTablet ? 16 : 12,
          horizontal: 18,
        ),
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: 1, color: context.themeColors.error),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Reset & Clear Data',
              style: context.themeText.smallParagraph?.copyWith(
                color: context.themeColors.error,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: context.themeSize.settingMenuIconSize,
              color: context.themeColors.error,
            ),
          ],
        ),
      ),
    );
  }
}
