import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';

/// Shows one account's ML-DSA-65 key in NEAR's form, as an animated UR QR
/// for a hot wallet or CLI to scan and as text for anyone copying it by hand.
///
/// The key is 1952 bytes, well past a single QR, hence the animation. The
/// `ml-dsa-65-hash:` handle under it is what NEAR lists on chain once the key
/// is added, so a user can confirm there that the key they added is this one.
class NearKeyExportScreen extends ConsumerStatefulWidget {
  final NearPublicKeyExport export;
  final String handle;

  const NearKeyExportScreen({super.key, required this.export, required this.handle});

  @override
  ConsumerState<NearKeyExportScreen> createState() => _NearKeyExportScreenState();
}

class _NearKeyExportScreenState extends ConsumerState<NearKeyExportScreen> {
  List<String>? _urParts;
  int? _urPartsBytes;
  bool _qrPaused = false;

  Future<void> _pauseAndTune() async {
    setState(() => _qrPaused = true);
    await BottomSheetContainer.show<void>(
      context,
      builder: (ctx) => const BottomSheetContainer(title: 'QR display options', child: QrTuningControls()),
    );
    if (mounted) setState(() => _qrPaused = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final settings = ref.watch(coldSettingsProvider);

    if (_urParts == null || _urPartsBytes != settings.qrBytes) {
      _urParts = encodeUrForQr(data: widget.export.encode(), maxFragmentLength: settings.qrBytes);
      _urPartsBytes = settings.qrBytes;
    }
    final parts = _urParts!;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'NEAR Public Key'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Scan with the device that prepares your NEAR transactions. Add this key to your NEAR account as a '
              'full access key, then transactions for that account can be signed here.',
              style: text.body.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedUrQr(parts: parts, fps: settings.qrFps, paused: _qrPaused),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${parts.length} ${parts.length == 1 ? 'frame' : 'frames'} · ${settings.qrFps} FPS · '
                  '${settings.qrBytes} bytes',
                  style: text.caption.copyWith(color: colors.textMuted),
                ),
                if (parts.length > 1) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _pauseAndTune,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: colors.bgSurface2, shape: BoxShape.circle),
                      child: Icon(Icons.pause_rounded, size: 20, color: colors.textContent),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            DetailSummaryRow.stacked(
              label: 'On-chain handle',
              value: widget.handle,
              monospace: true,
              note: 'How NEAR lists this key once it is added. Check it matches on the explorer.',
            ),
            DetailSummaryRow.stacked(label: 'Quantus account', value: widget.export.address, monospace: true),
            DetailSummaryRow.stacked(label: 'Full key', value: widget.export.nearPublicKey, monospace: true),
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
