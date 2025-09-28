import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class MigrationDialog extends StatefulWidget {
  final List<MigrationAccountData> migrationData;
  final Future<void> Function() onMigrate;
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
    required Future<void> Function() onMigrate,
    required VoidCallback onCancel,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width, // Ensure full width
      ),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    const Color(0xFF312E6E).useOpacity(0.4),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                color: Colors.black.useOpacity(0.3),
                child: MigrationDialog(
                  migrationData: migrationData,
                  onMigrate: onMigrate,
                  onCancel: onCancel,
                ),
              ),
            ),
          ),
        ],
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
    final accountCount = widget.migrationData.length;

    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: context.getHorizontalCenterPosition(
                230 + (24 * 2),
              ), // We add 24 * 2 because of the padding horizontal
              bottom: -100,
              child: const Sphere(variant: 7, size: 230),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Migrate your accounts',
                  style: context.themeText.mediumTitle,
                ),
                const SizedBox(height: 16),
                Text(
                  'We found existing accounts that need to be migrated to the new testnet. '
                  'This will update your account addresses while preserving your funds.',
                  style: context.themeText.smallParagraph,
                ),
                const SizedBox(height: 24),
                Text(
                  '$accountCount ${accountCount > 1 ? 'Accounts' : 'Account'} to migrate.',
                  style: context.themeText.paragraph?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.themeColors.yellow,
                  ),
                ),
                const SizedBox(height: 120),
                Button(
                  isLoading: _isMigrating,
                  variant: ButtonVariant.primary,
                  label: 'Migrate Accounts',
                  onPressed: () async {
                    setState(() => _isMigrating = true);

                    try {
                      await widget.onMigrate();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isMigrating = false);
                      }
                    }
                  },
                ),
                SizedBox(height: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
