import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_shared_components.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class CreateAccountView extends StatelessWidget {
  final Account draftAccount;
  final String draftChecksum;
  final bool isSaving;
  final bool isEditingName;
  final TextEditingController nameController;
  final VoidCallback onToggleEditingName;
  final VoidCallback onSubmit;

  const CreateAccountView({
    super.key,
    required this.draftAccount,
    required this.draftChecksum,
    required this.isSaving,
    required this.isEditingName,
    required this.nameController,
    required this.onToggleEditingName,
    required this.onSubmit,
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
                Text('Wallet Name', style: context.themeText.smallParagraph),
                const SizedBox(height: 12),
                _buildCreatedNameField(context),
                const SizedBox(height: 40),
                Text('Wallet Address', style: context.themeText.smallParagraph),
                const SizedBox(height: 12),
                _buildCreateField(
                  context,
                  value: AddressFormattingService.formatAddress(draftAccount.accountId),
                  onCopy: () => context.copyTextWithToaster(draftAccount.accountId),
                  textStyle: context.themeText.smallParagraph!.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 40),
                Text('Wallet Checkphrase', style: context.themeText.smallParagraph),
                const SizedBox(height: 12),
                _buildCreateField(
                  context,
                  value: draftChecksum,
                  onCopy: () => context.copyTextWithToaster(draftChecksum),
                  textStyle: context.themeText.smallParagraph!.copyWith(color: context.colors.accentPink),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GlassButton.simple(label: 'Create Account', isLoading: isSaving, onTap: onSubmit),
      ],
    );
  }

  Widget _buildCreatedNameField(BuildContext context) {
    return AccountField(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      trailing: AccountIconActionButton(
        icon: isEditingName ? Icons.check : Icons.edit_outlined,
        onTap: onToggleEditingName,
      ),
      child: TextField(
        controller: nameController,
        readOnly: !isEditingName || isSaving,
        style: context.themeText.smallParagraph,
        cursorColor: Colors.white,
        decoration: accountFieldDecoration,
      ),
    );
  }

  Widget _buildCreateField(
    BuildContext context, {
    required String value,
    required VoidCallback onCopy,
    required TextStyle textStyle,
  }) {
    return AccountField(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      trailing: AccountIconActionButton(icon: Icons.copy_outlined, onTap: onCopy),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
    );
  }
}
