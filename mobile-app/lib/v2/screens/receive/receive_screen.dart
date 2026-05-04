import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/address_details_card.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/share_account_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/segmented_controls.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

enum ReceiveTab { qrCode, address }

class ReceiveScreen extends ConsumerStatefulWidget {
  const ReceiveScreen({super.key});

  @override
  ConsumerState<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends ConsumerState<ReceiveScreen> {
  ReceiveTab _selectedTab = ReceiveTab.qrCode;
  String? _accountId;
  String? _checksum;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    final settingsService = ref.read(settingsServiceProvider);
    final checksumService = ref.read(humanReadableChecksumServiceProvider);

    try {
      final account = (await settingsService.getActiveAccount())!;
      final checksum = await checksumService.getHumanReadableName(account.account.accountId);
      setState(() {
        _accountId = account.account.accountId;
        _checksum = checksum;
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');

      if (mounted) {
        context.showErrorToaster(message: 'Error loading account data: $e');
      }
    }
  }

  void _share() {
    if (_accountId != null && _checksum != null) {
      shareAccountDetails(context, _accountId!, checksum: _checksum!);
    }
  }

  void _copyAccountDetails(BuildContext context) {
    context.copyTextWithToaster(
      'Account Id:\n$_accountId\n\nCheckphrase:\n$_checksum',
      message: 'Account details copied to clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const SegmentedControlItem(label: 'QR Code', value: ReceiveTab.qrCode),
      const SegmentedControlItem(label: 'Address', value: ReceiveTab.address),
    ];

    final isLoading = _accountId == null || _checksum == null;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Receive'),
      mainContent: Column(
        children: [
          SegmentedControls<ReceiveTab>(
            items: tabs,
            selectedValue: _selectedTab,
            onChanged: (value) {
              setState(() {
                _selectedTab = value;
              });
            },
          ),
          const SizedBox(height: 18),
          if (isLoading)
            const Expanded(child: Center(child: Loader()))
          else if (_selectedTab == ReceiveTab.qrCode)
            QrCodeTab(accountId: _accountId!, checksum: _checksum!)
          else
            AddressTab(accountId: _accountId!, checksum: _checksum!),
        ],
      ),
      bottomContent: _buildBottomContent(isLoading, _selectedTab),
    );
  }

  Widget? _buildBottomContent(bool isLoading, ReceiveTab selectedTab) {
    Widget content;

    if (isLoading) {
      return null;
    }

    if (_selectedTab == ReceiveTab.qrCode) {
      content = ShareAccountButton(onTap: _share, isDisabled: isLoading);
    } else {
      content = Row(
        children: [
          Expanded(
            child: QuantusButton.simple(
              label: 'Copy',
              onTap: () => _copyAccountDetails(context),
              isDisabled: isLoading,
              icon: Icon(Icons.copy, size: 20, color: context.colors.textPrimary),
              iconPlacement: IconPlacement.leading,
              variant: ButtonVariant.secondary,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ShareAccountButton(onTap: _share, isDisabled: isLoading),
          ),
        ],
      );
    }

    return ScaffoldBaseBottomContent(child: content);
  }
}

class QrCodeTab extends StatelessWidget {
  const QrCodeTab({super.key, required this.accountId, required this.checksum});

  final String accountId;
  final String checksum;

  @override
  Widget build(BuildContext context) {
    final qrSize = 267.0;
    final qrLogoSize = 64.0;

    return Expanded(
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.textTertiary, width: 1),
              borderRadius: BorderRadius.circular(16),
            ),
            width: qrSize,
            height: qrSize,
            child: QrImageView(
              data: accountId,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              embeddedImage: const AssetImage('assets/v2/uppercase_q_black_bg.png'),
              embeddedImageStyle: QrEmbeddedImageStyle(size: Size(qrLogoSize, qrLogoSize)),
              version: QrVersions.auto,
              size: qrSize,
              padding: const EdgeInsets.all(16),
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.white),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.white),
            ),
          ),

          const SizedBox(height: 12),
          Text(
            checksum,
            style: context.themeText.paragraph?.copyWith(color: context.colors.checksum),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),
          Text(
            accountId,
            style: context.themeText.smallParagraph?.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class AddressTab extends StatelessWidget {
  final String accountId;
  final String checksum;

  const AddressTab({super.key, required this.accountId, required this.checksum});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AddressDetailsCard(accountId: accountId, checksum: checksum),
    );
  }
}
