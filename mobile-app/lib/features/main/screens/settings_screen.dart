import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/list_item.dart';
import 'package:resonance_network_wallet/features/components/referral_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/reset_confirmation_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/authentication_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/notifications_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/select_wallet_for_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/show_recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
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
    final params = await _referralService.getShareLinkParameters(context.sharePositionRect());
    SharePlus.instance.share(params);
  }

  Future<void> _logout() async {
    try {
      await SubstrateService().logout();
      _referralService.invalidateCache();
      ref.read(pendingTransactionsProvider.notifier).clear(); // Clear specific notifier

      ref.read(accountsProvider.notifier).reset();
      ref.read(activeAccountProvider.notifier).reset();
      ref.read(accountAssociationsProvider.notifier).reset();

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()), // Or your login screen
          (route) => false,
        );
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('invalidating all providers');
        ref.invalidate(accountsProvider);
        ref.invalidate(activeAccountProvider);
        ref.invalidate(accountAssociationsProvider);
        ref.invalidate(pendingTransactionsProvider); // If needed for transactions
      });

      debugPrint('Logout successful');
    } catch (e) {
      debugPrint('Logout error: $e');
      if (mounted) {
        context.showErrorToaster(message: 'Logout failed: $e');
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

  void _navigateToRecoveryPhrase() {
    final accountsAsync = ref.read(accountsProvider);
    accountsAsync.whenData((accounts) {
      final walletIndices = getNonHardwareWalletIndices(accounts);

      if (walletIndices.isEmpty) {
        context.showErrorToaster(message: 'No wallets with recovery phrases found.');
        return;
      }

      if (walletIndices.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ShowRecoveryPhraseScreen(walletIndex: walletIndices.first)),
        );
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SelectWalletForRecoveryPhraseScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: WalletAppBar.simple(title: 'Wallet Settings'),
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
                if (AppConstants.globalDebug) ...[_buildDebugButton(context), const SizedBox(height: 22)],

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
        ListItem(
          title: 'Manage Accounts',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountsScreen()));
          },
        ),
        const SizedBox(height: 22),
        ListItem(
          title: 'Notifications',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsSettingsScreen()));
          },
        ),
        const SizedBox(height: 22),
        ListItem(
          title: 'Authentication',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthenticationSettingsScreen()));
          },
        ),
        const SizedBox(height: 22),
        ListItem(
          title: 'Show Recovery Phrase',
          onTap: () {
            _navigateToRecoveryPhrase();
          },
        ),
        const SizedBox(height: 22),
        ListItem(
          title: 'Referral',
          onTap: () {
            showReferralFormActionSheet(context, true);
          },
        ),
      ],
    );
  }

  Widget _buildInformationList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Information'),
        const SizedBox(height: 14),
        ListItem(
          title: 'Help & Support',
          onTap: () {
            final Uri url = Uri.parse(AppConstants.helpAndSupportUrl);
            launchUrl(url);
          },
          trailing: const Icon(Icons.arrow_outward_sharp),
          showArrow: false,
        ),
        const SizedBox(height: 22),
        ListItem(
          title: 'Invite & Share',
          onTap: _share,
          trailing: Icon(Icons.share_outlined, size: context.themeSize.settingMenuShareIconSize),
        ),
        const SizedBox(height: 22),
        ListItem(
          title: 'Term of Service',
          onTap: () {
            final Uri url = Uri.parse(AppConstants.termsOfServiceUrl);
            launchUrl(url);
          },
          trailing: const Icon(Icons.arrow_outward_sharp),
          showArrow: false,
        ),
      ],
    );
  }

  Widget _buildResetButton(BuildContext context) {
    return GestureDetector(
      onTap: _showResetConfirmationSheet,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: context.isTablet ? 16 : 12, horizontal: 18),
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
              style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.error),
            ),
            Icon(Icons.arrow_forward_ios, size: context.themeSize.settingMenuIconSize),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugButton(BuildContext context) {
    return GestureDetector(
      onTap: _createDebugOldAccounts,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: context.isTablet ? 16 : 12, horizontal: 18),
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Colors.orange),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Debug: Create Old Accounts', style: context.themeText.smallParagraph?.copyWith(color: Colors.orange)),
            Icon(Icons.bug_report, size: context.themeSize.settingMenuIconSize, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Future<void> _createDebugOldAccounts() async {
    try {
      final migrationService = MigrationService(_settingsService, HdWalletService());
      await migrationService.createDebugOldAccounts();

      if (mounted) {
        context.showWarningToaster(
          message: 'Created debug old accounts with indices 0 and 1. Restart app to see migration dialog.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showErrorToaster(message: 'Failed to create debug accounts: ${e.toString()}');
      }
    }
  }
}
