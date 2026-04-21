import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_shared_components.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class EditAccountView extends StatelessWidget {
  final Account account;
  final String checksum;
  final bool isEditingName;
  final bool isSavingName;
  final TextEditingController nameController;
  final VoidCallback onToggleEditingName;
  final VoidCallback onSaveName;

  const EditAccountView({
    super.key,
    required this.account,
    required this.checksum,
    required this.isEditingName,
    required this.isSavingName,
    required this.nameController,
    required this.onToggleEditingName,
    required this.onSaveName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account Name', style: context.themeText.smallParagraph),
                const SizedBox(height: 12),
                _buildAccountNameField(context),
                const SizedBox(height: 40),
                Text('Address Details', style: context.themeText.smallParagraph),
                const SizedBox(height: 12),
                _buildAddressDetails(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        QuantusButton.simple(
          label: 'Share Account Details',
          onTap: () => shareAccountDetails(context, account.accountId, checksum: checksum),
        ),
      ],
    );
  }

  Widget _buildAccountNameField(BuildContext context) {
    return AccountField(
      trailing: isSavingName
          ? const SizedBox(width: 40, height: 40, child: Center(child: Loader()))
          : AccountIconActionButton(
              icon: isEditingName ? Icons.check : Icons.edit_outlined,
              onTap: () {
                if (isEditingName) {
                  onSaveName();
                } else {
                  onToggleEditingName();
                }
              },
            ),
      child: TextField(
        controller: nameController,
        readOnly: !isEditingName || isSavingName,
        style: context.themeText.smallParagraph!.copyWith(
          fontWeight: FontWeight.w500,
          color: context.colors.accentOrange,
        ),
        cursorColor: context.colors.accentOrange,
        decoration: accountFieldDecoration,
        onSubmitted: (_) {
          if (isEditingName && !isSavingName) {
            onSaveName();
          }
        },
        onTap: () {
          if (!isEditingName) {
            onToggleEditingName();
          }
        },
      ),
    );
  }

  Widget _buildAddressDetails(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          AccountCopyRow(
            value: account.accountId,
            onCopy: () => context.copyTextWithToaster(account.accountId),
            textStyle: context.themeText.smallParagraph!.copyWith(fontWeight: FontWeight.w500),
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 8),
          AccountCopyRow(
            value: checksum,
            onCopy: () => context.copyTextWithToaster(checksum, message: 'Checkphrase copied to clipboard'),
            textStyle: context.themeText.smallParagraph!.copyWith(color: context.colors.checksum),
          ),
        ],
      ),
    );
  }
}
