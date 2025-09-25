import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AccountSettingsScreen extends StatefulWidget {
  final Account account;
  final String balance;
  final String checksumName;

  const AccountSettingsScreen({
    super.key,
    required this.account,
    required this.balance,
    required this.checksumName,
  });

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  void _editAccountName() {
    Navigator.push<bool?>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateAccountScreen(accountToEdit: widget.account),
      ),
    ).then((result) {
      if (result == true && mounted) {
        // Pop this screen with a result to force a refresh on the previous one
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      decorations: [
        Positioned(
          right: -50,
          top: context.containerHalfHeight,
          child: const Sphere(variant: 2, size: 194),
        ),
      ],
      appBar: 'Account Settings',
      child: Stack(
        children: [
          Positioned(
            left: context.getHorizontalCenterPosition(
              (context.isTablet ? 80.0 : 60.0) + 32,
            ),
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
              const SizedBox(height: 20),
              _buildSecuritySection(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          decoration: ShapeDecoration(
            color: context.themeColors.settingCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildAccountHeader() {
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
                  Text(
                    widget.account.name,
                    style: context.themeText.smallTitle,
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit, color: Colors.white70, size: 16),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.checksumName,
              style: context.themeText.smallParagraph?.copyWith(
                color: context.themeColors.checksum,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.balance,
              style: context.themeText.smallParagraph?.copyWith(
                color: context.themeColors.light,
              ),
            ),
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
          padding: const EdgeInsets.only(
            left: 10.0,
            top: 8.5,
            bottom: 8.5,
            right: 18.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Share Account Details', style: context.themeText.paragraph),
              Icon(
                Icons.share,
                color: context.themeColors.textPrimary,
                size: context.isTablet ? 26 : 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return _buildSettingCard(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 10.0,
          left: 10.0,
          bottom: 10.0,
          right: 18.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: context.isTablet ? 550 : 251,
              child: Text(
                context.isTablet
                    ? widget.account.accountId
                    : AddressFormattingService.splitIntoChunks(
                        widget.account.accountId,
                      ).join(' '),
                style: context.themeText.smallParagraph,
              ),
            ),
            InkWell(
              child: Icon(
                Icons.copy,
                color: Colors.white,
                size: context.isTablet ? 26 : 22,
              ),
              onTap: () => ClipboardExtensions.copyTextWithSnackbar(
                context,
                widget.account.accountId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _buildSettingCard(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 12.0,
          left: 12.0,
          bottom: 12.0,
          right: 26.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/high_security_icon.svg',
                  width: context.isTablet ? 28 : 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('High Security', style: context.themeText.largeTag),
                    Text(
                      'COMING SOON',
                      style: context.themeText.detail?.copyWith(
                        color: context.themeColors.checksum,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
