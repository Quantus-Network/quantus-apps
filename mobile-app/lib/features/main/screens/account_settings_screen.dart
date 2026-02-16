import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/account_tag.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_details_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_get_started_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/svg_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/utils/feature_flags.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  final BaseAccount account;
  final String balance;
  final String checksumName;
  final bool isHighSecurity;
  final bool isEntrustedAccount;
  const AccountSettingsScreen({
    super.key,
    required this.account,
    required this.balance,
    required this.checksumName,
    required this.isHighSecurity,
    required this.isEntrustedAccount,
  });

  @override
  ConsumerState<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  void _editAccountName() {
    if (widget.account is! Account) return;

    Navigator.push<bool?>(
      context,
      MaterialPageRoute(builder: (context) => CreateAccountScreen(accountToEdit: widget.account as Account)),
    ).then((result) {
      if (result == true && mounted) {
        // Pop this screen with a result to force a refresh on the previous one
        Navigator.of(context).pop(true);
      }
    });
  }

  Widget _buildDisconnectWalletButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Button(
        label: 'Disconnect Wallet',
        onPressed: _showDisconnectConfirmation,
        variant: ButtonVariant.dangerOutline,
      ),
    );
  }

  void _showDisconnectConfirmation() {
    showAppModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
              decoration: ShapeDecoration(
                color: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.close, size: context.themeSize.overlayCloseIconSize),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('Disconnect Wallet?', style: context.themeText.mediumTitle),
                    const SizedBox(height: 13),
                    Text(
                      'This will remove this account from your wallet. If this is the last account for this hardware wallet, the wallet connection will be removed.',
                      style: context.themeText.smallParagraph,
                    ),
                    const SizedBox(height: 28),
                    Button(
                      variant: ButtonVariant.danger,
                      label: 'Disconnect',
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _disconnectWallet();
                      },
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: context.themeText.smallParagraph?.copyWith(decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _disconnectWallet() async {
    if (widget.account is! Account) return;

    try {
      final accountsService = AccountsService();
      await accountsService.removeAccount(widget.account as Account);
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      ref.invalidate(accountAssociationsProvider);
      ref.invalidate(balanceProviderFamily(widget.account.accountId));

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate change
      }
    } catch (e) {
      print('Failed to disconnect: $e');
      if (mounted) {
        context.showErrorToaster(message: 'Failed to disconnect wallet: $e');
      }
    }
  }

  bool get isKeystoneAccount =>
      widget.account is Account && (widget.account as Account).accountType == AccountType.keystone;

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      decorations: [
        Positioned(right: -50, top: context.containerHalfHeight, child: const Sphere(variant: 2, size: 194)),
      ],
      appBar: WalletAppBar(title: 'Account Settings'),
      child: Stack(
        children: [
          Positioned(
            left: context.getHorizontalCenterPosition((context.isTablet ? 80.0 : 60.0) + 48),
            child: AccountGradientImage(
              accountId: widget.account.accountId,
              width: context.isTablet ? 80.0 : 60.0,
              height: context.isTablet ? 80.0 : 60.0,
            ),
          ),

          Column(
            children: [
              const SizedBox(height: 30),
              _buildAccountHeader(),
              const SizedBox(height: 27),
              _buildShareSection(),
              const SizedBox(height: 20),
              _buildAddressSection(),
              if (FeatureFlags.enableHighSecurity) ...[const SizedBox(height: 20), _buildHighSecuritySection(context)],
              if (isKeystoneAccount) ...[const SizedBox(height: 20), _buildDisconnectWalletButton()],
              const SizedBox(height: 30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required Widget child, Color? color}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: ShapeDecoration(
            color: color ?? context.themeColors.settingCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAccountHeader() {
    final isHighSecurity = widget.isHighSecurity && FeatureFlags.enableHighSecurity;
    final isEntrustedAccount = widget.isEntrustedAccount;
    return _buildSettingCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            InkWell(
              onTap: _editAccountName,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(widget.account.name, style: context.themeText.smallTitle),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, color: Colors.white70, size: 16),
                ],
              ),
            ),
            if (isHighSecurity) ...[
              const SizedBox(height: 10),
              AccountTag(text: 'High-Security', color: context.themeColors.accountTagHighSecurity, width: 177.0),
            ],
            if (isEntrustedAccount) ...[
              const SizedBox(height: 10),
              AccountTag(text: 'Entrusted Account', color: context.themeColors.accountTagEntrusted, width: 177.0),
            ],
            const SizedBox(height: 10),
            Text(
              widget.checksumName,
              style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            Text(widget.balance, style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.light)),
          ],
        ),
      ),
    );
  }

  Widget _buildShareSection() {
    return _buildSettingCard(
      child: InkWell(
        onTap: () {
          showReceiveSheet(context, isReceiving: false);
        },
        child: Padding(
          padding: const EdgeInsets.only(left: 10.0, top: 8.5, bottom: 8.5, right: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Share Account Details', style: context.themeText.paragraph),
              Icon(Icons.share, color: context.themeColors.textPrimary, size: context.isTablet ? 26 : 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return _buildSettingCard(
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0, left: 10.0, bottom: 10.0, right: 18.0),
        child: InkWell(
          onTap: () => context.copyTextWithToaster(widget.account.accountId),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: context.isTablet ? 550 : 251,
                child: Text(
                  context.isTablet
                      ? widget.account.accountId
                      : AddressFormattingService.splitIntoChunks(widget.account.accountId).join(' '),
                  style: context.themeText.smallParagraph,
                ),
              ),
              InkWell(
                child: const CopyIcon(),
                onTap: () => context.copyTextWithToaster(widget.account.accountId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighSecuritySection(BuildContext context) {
    final isHighSecurity = widget.isHighSecurity && FeatureFlags.enableHighSecurity;
    final isEntrustedAccount = widget.isEntrustedAccount;
    final textColor = isHighSecurity ? context.themeColors.textSecondary : context.themeColors.textPrimary;
    final secondRowTextColor = isHighSecurity ? context.themeColors.darkGray : context.themeColors.textPrimary;
    final iconColor = isHighSecurity ? context.themeColors.textSecondary : context.themeColors.checksum;
    final buttonBackgroundColor = isHighSecurity ? context.themeColors.checksum : context.themeColors.settingCard;
    final subtitle = 'VIEW SETTINGS';

    return _buildSettingCard(
      color: buttonBackgroundColor,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => isHighSecurity || isEntrustedAccount
                  ? HighSecurityDetailsScreen(account: widget.account)
                  : HighSecurityGetStartedScreen(account: widget.account as Account),
            ),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 12, left: 12, right: 26, bottom: 12),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 60,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 12,
                children: [
                  SvgPictureExtensions.assetWithColor(
                    'assets/high_security_icon.svg',
                    width: context.isTablet ? 28 : 20,
                    color: iconColor,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text('High Security', style: context.themeText.largeTag?.copyWith(color: textColor)),
                      if (isHighSecurity || isEntrustedAccount) ...[
                        Text(subtitle, style: context.themeText.tag?.copyWith(color: secondRowTextColor)),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
