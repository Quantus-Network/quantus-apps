import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

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
      isDismissible: false,
      enableDrag: false,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (ctx) => MigrationDialog(migrationData: migrationData, onMigrate: onMigrate, onTryLater: onTryLater),
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
    final colors = context.colors;
    final text = context.themeText;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      decoration: BoxDecoration(
        color: colors.sheetBackground,
        border: Border.all(color: const Color(0xFF3D3D3D)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Migrate your accounts', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
          const SizedBox(height: 24),
          Text(
            'We\'ll record your old\u2011chain testnet rewards and actions to determine '
            'rewards on the new Quantus Testnet.\n\n'
            'Balances do not migrate.\n\n'
            'Use the new testnet faucet for funds.',
            style: text.smallParagraph?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            '$accountCount ${accountCount > 1 ? 'Accounts' : 'Account'} to migrate.',
            style: text.paragraph?.copyWith(fontWeight: FontWeight.w600, color: colors.accentGreen),
          ),
          const SizedBox(height: 40),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: colors.error.useOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(_errorMessage!, style: text.smallParagraph?.copyWith(color: colors.textError)),
            ),
          GlassButton.simple(
            label: _errorMessage != null ? 'Retry' : 'Migrate Accounts',
            isLoading: _isMigrating,
            onTap: () async {
              setState(() => _isMigrating = true);
              try {
                await widget.onMigrate();
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.of(context).pop();
              } catch (e) {
                if (mounted) {
                  setState(() => _errorMessage = 'We couldn\'t upload migration data. Please retry or try later.');
                }
              } finally {
                if (mounted) setState(() => _isMigrating = false);
              }
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            GlassButton.simple(
              label: 'Try later',
              variant: ButtonVariant.transparent,
              onTap: () async {
                if (widget.onTryLater != null) await widget.onTryLater!();
                // ignore: use_build_context_synchronously
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }
}
