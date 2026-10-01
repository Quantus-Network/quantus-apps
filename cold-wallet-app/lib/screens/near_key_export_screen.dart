import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/ur_qr_panel.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';

/// Shows one account's ML-DSA-65 key in NEAR's form, as an animated UR QR
/// and as selectable text with a copy control.
///
/// The key is 1952 bytes, well past a single QR, hence the animation. The
/// `ml-dsa-65-hash:` handle under it is what NEAR lists on chain once the key
/// is added, so a user can confirm there that the key they added is this one.
/// Nothing here touches NEAR: adding the key to an account is done elsewhere,
/// with `near account add-key` or a wallet that reads this export.
class NearKeyExportScreen extends StatelessWidget {
  final NearPublicKeyExport export;
  final String handle;

  const NearKeyExportScreen({super.key, required this.export, required this.handle});

  Future<void> _copyKey(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: export.nearPublicKey));
    if (!context.mounted) return;
    final colors = context.colorsV3;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('NEAR public key copied', style: context.themeTextV3.body.copyWith(color: colors.textContent)),
        backgroundColor: colors.bgSurface2,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'NEAR Public Key'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'This is the account\'s key in NEAR\'s form. Add it to a NEAR account as a full access key — for now '
              'by copying the key into the NEAR CLI, as the Quantus hot wallet does not yet read this QR — and '
              'transactions for that account can then be reviewed and signed here.',
              style: text.body.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            UrQrPanel(payload: UrPayload(export.encode())),
            const SizedBox(height: 24),
            DetailSummaryRow.stacked(
              label: 'On-chain handle',
              value: handle,
              monospace: true,
              note: 'How NEAR lists this key once it is added. Check it matches on the explorer.',
            ),
            DetailSummaryRow.stacked(label: 'Quantus account', value: export.address, monospace: true),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('FULL KEY', style: text.labelData.copyWith(color: colors.textMuted)),
                      ),
                      QuantusIconButton.ghost(
                        icon: Icons.copy_rounded,
                        size: IconButtonSize.small,
                        onTap: () => _copyKey(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SelectableText(export.nearPublicKey, style: text.dataAddress.copyWith(color: colors.textContent)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', onTap: () => Navigator.pop(context)),
      ),
    );
  }
}
