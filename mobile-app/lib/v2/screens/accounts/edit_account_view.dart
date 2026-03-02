import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';

class EditAccountView extends StatelessWidget {
  final Account account;
  final String checksum;
  final bool isEditingName;
  final bool isSavingName;
  final TextEditingController nameController;
  final VoidCallback onBack;
  final VoidCallback onToggleEditingName;
  final VoidCallback onSaveName;

  const EditAccountView({
    super.key,
    required this.account,
    required this.checksum,
    required this.isEditingName,
    required this.isSavingName,
    required this.nameController,
    required this.onBack,
    required this.onToggleEditingName,
    required this.onSaveName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 40),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Account Name', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildAccountNameField(context),
                const SizedBox(height: 40),
                Text('Address Details', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildAddressDetails(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Button(
          label: 'Share Account Details',
          onTap: () => shareAccountDetails(context, account.accountId, checksum: checksum),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
        ),
        const Text(
          'Edit Account',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1,
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
          splashRadius: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
        ),
      ],
    );
  }

  Widget _buildAccountNameField(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: nameController,
              readOnly: !isEditingName || isSavingName,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.accentPink,
                height: 1.35,
              ),
              cursorColor: context.colors.accentPink,
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
          ),
          isSavingName
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : _buildIconActionButton(
                  icon: isEditingName ? Icons.check : Icons.edit_outlined,
                  iconSize: 20,
                  onTap: () {
                    if (isEditingName) {
                      onSaveName();
                    } else {
                      onToggleEditingName();
                    }
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildAddressDetails(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _buildCopyRow(
            context,
            value: account.accountId,
            onCopy: () => context.copyTextWithToaster(account.accountId),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.35,
            ),
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 8),
          _buildCopyRow(
            context,
            value: checksum,
            onCopy: () => context.copyTextWithToaster(checksum),
            textStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.colors.accentPink,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow(
    BuildContext context, {
    required String value,
    required VoidCallback onCopy,
    required TextStyle textStyle,
    int? maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(value, maxLines: maxLines, overflow: overflow, style: textStyle),
        ),
        const SizedBox(width: 8),
        _buildIconActionButton(icon: Icons.copy_outlined, isTiny: true, iconSize: 12, onTap: onCopy),
      ],
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
