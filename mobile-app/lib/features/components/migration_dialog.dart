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
  final Future<void> Function()? onTryLater;

  const MigrationDialog({super.key, required this.migrationData, required this.onMigrate, this.onTryLater});

  static Future<void> show({
    required BuildContext context,
    required List<MigrationAccountData> migrationData,
    required Future<void> Function() onMigrate,
    Future<void> Function()? onTryLater,
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
                  colors: [Colors.black, const Color(0xFF312E6E).useOpacity(0.4), Colors.black],
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
                child: MigrationDialog(migrationData: migrationData, onMigrate: onMigrate, onTryLater: onTryLater),
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
  String? _errorMessage;

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
                Text('Migrate your accounts', style: context.themeText.mediumTitle),
                const SizedBox(height: 16),
                Text(
                  'We\'ll record your old‑chain mining rewards and actions to determine '
                  'airdrops and rewards on the new Quantus Testnet.\n\n'
                  'Balances do not migrate. Use the new testnet faucet for funds; '
                  'mining on the new testnet will earn rewards again.',
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
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: context.themeColors.error.useOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.error),
                    ),
                  ),
                ],
                Button(
                  isLoading: _isMigrating,
                  variant: ButtonVariant.primary,
                  label: _errorMessage != null ? 'Retry' : 'Migrate Accounts',
                  onPressed: () async {
                    setState(() {
                      _isMigrating = true;
                    });

                    try {
                      await widget.onMigrate();
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _errorMessage = 'We couldn\'t upload migration data. Please retry or try later.';
                        });
                      }
                    } finally {
                      if (mounted) {
                        setState(() => _isMigrating = false);
                      }
                    }
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Button(
                    variant: ButtonVariant.transparent,
                    label: 'Try later',
                    onPressed: () async {
                      if (widget.onTryLater != null) {
                        await widget.onTryLater!();
                      }
                      if (mounted) {
                        // ignore: use_build_context_synchronously
                        Navigator.of(context).pop();
                      }
                    },
                    textStyle: context.themeText.smallParagraph?.copyWith(decoration: TextDecoration.underline),
                  ),
                ],
                const SizedBox(height: 48),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
