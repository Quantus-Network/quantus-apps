import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/referral_and_reward_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/reset_confirmation_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/authentication_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/show_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  final ReferralService _referralService = ReferralService();

  void _resetAndClearData() {
    _settingsService.clearAll();
    _logout();
  }

  Future<void> _share() async {
    final params = await _referralService.getShareLinkParameters();
    SharePlus.instance.share(params);
  }

  Future<void> _logout() async {
    try {
      await SubstrateService().logout();
      _referralService.invalidateRewardProgramCache();
      ref
          .read(pendingTransactionsProvider.notifier)
          .clear(); // Clear specific notifier

      ref.read(accountsProvider.notifier).reset();
      ref.read(activeAccountProvider.notifier).reset();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const WelcomeScreen(),
          ), // Or your login screen
          (route) => false,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('invalidating all providers');
        ref.invalidate(accountsProvider);
        ref.invalidate(activeAccountProvider);
        ref.invalidate(
          pendingTransactionsProvider,
        ); // If needed for transactions
      });

      debugPrint('Logout successful');
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        showTopSnackBar(context, title: 'Error', message: 'Logout failed: $e');
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
    return ScaffoldBase(
      screenTitle: ScreenTitle(title: 'Wallet Settings'),
      extendBodyBehindAppBar: true,
      extendBodyBehindNavBar: true,
      decorations: [
        Positioned(
          bottom: -20,
          left: context.getHorizontalCenterPosition(251.62),
          child: const Sphere(variant: 8, size: 251.62),
        ),
      ],
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildSettingsList(context),
                const SizedBox(height: 35),
                _buildInformationList(context),
                const SizedBox(height: 42),
                const SizedBox(height: 22),
                _buildResetButton(context),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: context.themeText.largeTag);
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingsItem(context, 'Manage Accounts', () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AccountsScreen()),
          );
        }),
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
        const SizedBox(height: 22),
        _buildSettingsItem(context, 'Referral', () {
          showReferralAndRewardActionSheet(
            context,
            currentNavbarIndex: 2, // settings screen index
            showRewardProgram: false, // only show referral code section
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
        const SizedBox(height: 14),
        _buildSettingsItem(
          context,
          'Help & Support',
          () {
            final Uri url = Uri.parse(AppConstants.helpAndSupportUrl);
            launchUrl(url);
          },
          trailing: const Icon(Icons.arrow_outward_sharp),
          showArrow: false,
        ),
        const SizedBox(height: 22),
        _buildSettingsItem(
          context,
          'Invite & Share',
          _share,
          trailing: Icon(
            Icons.share_outlined,
            size: context.themeSize.settingMenuShareIconSize,
          ),
        ),
        const SizedBox(height: 22),
        _buildSettingsItem(
          context,
          'Term of Service',
          () {
            final Uri url = Uri.parse(AppConstants.termsOfServiceUrl);
            launchUrl(url);
          },
          trailing: const Icon(Icons.arrow_outward_sharp),
          showArrow: false,
        ),
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
          color: context.themeColors.buttonGlass,
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
            ),
          ],
        ),
      ),
    );
  }
}
