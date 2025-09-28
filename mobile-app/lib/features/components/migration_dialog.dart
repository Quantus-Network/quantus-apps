import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class MigrationDialog extends StatefulWidget {
  final List<MigrationAccountData> migrationData;
  final VoidCallback onMigrate;
  final VoidCallback onCancel;

  const MigrationDialog({
    super.key,
    required this.migrationData,
    required this.onMigrate,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required List<MigrationAccountData> migrationData,
    required VoidCallback onMigrate,
    required VoidCallback onCancel,
  }) {
    return showAppModalBottomSheet(
      context: context,
      builder: (context) => MigrationDialog(
        migrationData: migrationData,
        onMigrate: onMigrate,
        onCancel: onCancel,
      ),
    );
  }

  @override
  State<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends State<MigrationDialog> {
  bool _isMigrating = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
          decoration: ShapeDecoration(
            color: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: context.themeSize.overlayCloseIconSize,
                    ),
                    onPressed: widget.onCancel,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Migrating your account to the new Quantus Testnet',
                  style: context.themeText.mediumTitle,
                ),
                const SizedBox(height: 16),
                Text(
                  'We found existing accounts that need to be migrated to the new testnet. '
                  'This will update your account addresses while preserving your funds.',
                  style: context.themeText.smallParagraph,
                ),
                const SizedBox(height: 28),
                Text(
                  '${widget.migrationData.length} Accounts to migrate:',
                  style: context.themeText.smallTitle,
                ),
                // const SizedBox(height: 16),
                // ...widget.migrationData.map((data) => _buildAccountItem(data)),
                const SizedBox(height: 28),
                if (_isMigrating)
                  const Center(child: CircularProgressIndicator())
                else
                  Button(
                    variant: ButtonVariant.primary,
                    label: 'Migrate Accounts',
                    onPressed: () async {
                      setState(() => _isMigrating = true);
                      try {
                        widget.onMigrate();
                      } finally {
                        if (mounted) {
                          setState(() => _isMigrating = false);
                        }
                      }
                    },
                    textStyle: context.themeText.smallTitle?.copyWith(
                      color: context.themeColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: widget.onCancel,
                    child: Text(
                      'Cancel',
                      style: context.themeText.smallParagraph?.copyWith(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem(MigrationAccountData data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.themeColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Account ${data.oldAccount.index}',
                style: context.themeText.smallTitle,
              ),
              const SizedBox(width: 8),
              Text(data.oldAccount.name, style: context.themeText.detail),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Address: ${data.oldAccount.accountId}',
            style: context.themeText.detail,
          ),
          const SizedBox(height: 4),
          Text(
            'Public Key: ${data.publicKeyHex}',
            style: context.themeText.detail,
          ),
          const SizedBox(height: 4),
          Text(
            'New Address: ${data.newAccountId}',
            style: context.themeText.detail?.copyWith(
              color: context.themeColors.buttonSuccess,
            ),
          ),
        ],
      ),
    );
  }
}
