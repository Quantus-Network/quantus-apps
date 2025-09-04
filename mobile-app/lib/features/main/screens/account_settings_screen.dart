import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
      appBar: const WalletAppBar(title: 'Account Settings'),
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
              const SizedBox(height: 20),
              _buildAccountHeader(),
              const SizedBox(height: 40),
              _buildAddressSection(),
              const SizedBox(height: 20),
              _buildSecuritySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountHeader() {
    return Column(
      children: [
        // Placeholder for account icon
        AccountGradientImage(
          accountId: widget.account.accountId,
          width: context.isTablet ? 80.0 : 60.0,
          height: context.isTablet ? 80.0 : 60.0,
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _editAccountName,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.account.name, style: context.themeText.largeTag),
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
    );
  }

  Widget _buildAddressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: context.isTablet ? 12 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF313131),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (!context.isTablet) const Expanded(child: SizedBox()),
            SizedBox(
              width: context.isTablet ? 550 : 180,
              child: Text(
                context.isTablet
                    ? widget.account.accountId
                    : AddressFormattingService.splitIntoChunks(
                        widget.account.accountId,
                      ).join(' '),
                textAlign: context.isTablet
                    ? TextAlign.start
                    : TextAlign.center,
                style: context.themeText.smallParagraph,
              ),
            ),
            if (!context.isTablet) const Expanded(child: SizedBox()),
            IconButton(
              icon: Icon(
                Icons.copy,
                color: Colors.white,
                size: context.isTablet ? 26 : 22,
              ),
              onPressed: () => ClipboardExtensions.copyTextWithSnackbar(
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF313131),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(
                  'assets/lock_icon.svg',
                  width: context.isTablet ? 28 : 20,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High Security Features',
                      style: context.themeText.largeTag,
                    ),
                    Text(
                      'COMING SOON',
                      style: context.themeText.detail?.copyWith(
                        color: const Color(0xFFFADC34),
                        fontWeight: FontWeight.w600,
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
