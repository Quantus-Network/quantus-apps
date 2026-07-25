import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/address_details_card.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_qr.dart';
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
      var accountId = account.account.accountId;
      // Encrypted accounts rotate deposits to the next unused wormhole address
      // (shared linearly with change addresses) so deposits aren't linkable.
      final base = account.account;
      if (isEncryptedAccount(base)) {
        final service = ref.read(encryptedAccountServiceProvider((base as Account).walletIndex));
        accountId = (await service.receiveKeyPair()).address;
      }
      final checksum = await checksumService.getHumanReadableName(accountId);
      if (!mounted) return;
      setState(() {
        _accountId = accountId;
        _checksum = checksum;
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');

      if (mounted) {
        final l10n = ref.read(l10nProvider);
        context.showErrorToaster(message: l10n.receiveErrorLoadingAccount('$e'));
      }
    }
  }

  void _share() {
    if (_accountId != null && _checksum != null) {
      shareAccountDetails(context, _accountId!, checksum: _checksum!);
    }
  }

  void _copyAddress(BuildContext context) {
    final l10n = ref.read(l10nProvider);
    context.copyTextWithToaster(_accountId!, message: l10n.receiveCopiedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final tabs = [
      SegmentedControlItem(label: l10n.receiveTabQrCode, value: ReceiveTab.qrCode),
      SegmentedControlItem(label: l10n.receiveTabAddress, value: ReceiveTab.address),
    ];

    final isLoading = _accountId == null || _checksum == null;

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.receiveTitle),
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
      bottomContent: _buildBottomContent(l10n, isLoading, _selectedTab),
    );
  }

  Widget? _buildBottomContent(AppLocalizations l10n, bool isLoading, ReceiveTab selectedTab) {
    Widget content;

    if (isLoading) {
      return null;
    }

    if (_selectedTab == ReceiveTab.qrCode) {
      content = Row(
        children: [
          Expanded(
            child: QuantusButton.simple(
              label: l10n.receiveCopy,
              onTap: () => _copyAddress(context),
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
    } else {
      content = ShareAccountButton(onTap: _share, isDisabled: isLoading);
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
    return Expanded(
      child: Column(
        children: [
          QuantusQr(accountId: accountId),
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
