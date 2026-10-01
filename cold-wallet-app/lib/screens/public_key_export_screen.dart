import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/ur_qr_panel.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';

/// Shows one account's full ML-DSA-65 public key, as an animated UR QR and
/// as selectable text with a copy control.
///
/// A Quantus address is a hash of the key, so anything that registers the key
/// itself needs this screen. The key is a Quantus key first; NEAR is the one
/// other system that accepts ML-DSA-65 keys today, so the text form is the
/// `ml-dsa-65:<base58>` encoding NEAR reads, and the `ml-dsa-65-hash:` handle
/// is how NEAR would list the key if it were added to an account there.
/// Nothing here touches any chain: registering the key is done elsewhere.
class PublicKeyExportScreen extends StatelessWidget {
  final NearPublicKeyExport export;
  final String handle;

  const PublicKeyExportScreen({super.key, required this.export, required this.handle});

  Future<void> _copyKey(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: export.nearPublicKey));
    if (!context.mounted) return;
    final colors = context.colorsV3;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Public key copied', style: context.themeTextV3.body.copyWith(color: colors.textContent)),
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
      appBar: const V2AppBar(title: 'Public Key'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'The account\'s full ML-DSA-65 public key. Your Quantus address is a hash of it; show the key itself '
              'only where a key is registered directly. It is written in the ml-dsa-65:<base58> form NEAR reads: '
              'to put it on a NEAR account, paste it into the NEAR CLI for now, as the Quantus hot wallet does not '
              'yet read this QR. Transactions for that account can then be reviewed and signed here.',
              style: text.body.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            UrQrPanel(payload: UrPayload(export.encode())),
            const SizedBox(height: 24),
            DetailSummaryRow.stacked(
              label: 'If added to a NEAR account',
              value: handle,
              monospace: true,
              note: 'NEAR lists keys by this handle rather than the key itself. Check it matches on the explorer.',
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
