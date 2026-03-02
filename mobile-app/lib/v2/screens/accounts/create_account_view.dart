import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class CreateAccountView extends StatelessWidget {
  final Account draftAccount;
  final String draftChecksum;
  final bool isSaving;
  final bool isEditingName;
  final TextEditingController nameController;
  final VoidCallback onBack;
  final VoidCallback onToggleEditingName;
  final VoidCallback onSubmit;

  const CreateAccountView({
    super.key,
    required this.draftAccount,
    required this.draftChecksum,
    required this.isSaving,
    required this.isEditingName,
    required this.nameController,
    required this.onBack,
    required this.onToggleEditingName,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSheetHeader(context, title: 'New Account', onBack: onBack),
        const SizedBox(height: 40),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet Name', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildCreatedNameField(context),
                const SizedBox(height: 40),
                Text('Wallet Address', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildCreateField(
                  context,
                  value: AddressFormattingService.formatAddress(draftAccount.accountId),
                  onCopy: () => context.copyTextWithToaster(draftAccount.accountId),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 40),
                Text('Wallet Checkphrase', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildCreateField(
                  context,
                  value: draftChecksum,
                  onCopy: () => context.copyTextWithToaster(draftChecksum),
                  textStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.colors.accentPink,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Button(
          label: 'Create Account',
          isLoading: isSaving,
          onTap: onSubmit,
        ),
      ],
    );
  }

  Widget _buildSheetHeader(BuildContext context, {required String title, VoidCallback? onBack}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: onBack == null
              ? const SizedBox()
              : IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1,
          ),
        ),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildCreatedNameField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: nameController,
              readOnly: !isEditingName || isSaving,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _buildIconActionButton(
            icon: isEditingName ? Icons.check : Icons.edit_outlined,
            iconSize: 20,
            onTap: onToggleEditingName,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateField(
    BuildContext context, {
    required String value,
    required VoidCallback onCopy,
    required TextStyle textStyle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
          ),
          const SizedBox(width: 8),
          _buildIconActionButton(icon: Icons.copy_outlined, iconSize: 20, onTap: onCopy),
        ],
      ),
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
    bool isTiny = false,
  }) {
    final double size = isTiny ? 20 : 40;
    final asset = isTiny ? GlassContainer.tinyAsset : GlassContainer.smallAsset;
    return SizedBox(
      width: size,
      height: size,
      child: GlassContainer(
        asset: asset,
        onTap: onTap,
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }
}
