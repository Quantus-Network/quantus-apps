import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';

/// Shows [signed] as an animated UR QR for the hot wallet to scan, with the
/// frame-size and speed controls the user tuned in settings.
class SignatureQrView extends ConsumerStatefulWidget {
  final Uint8List signed;
  final String instruction;

  const SignatureQrView({super.key, required this.signed, required this.instruction});

  @override
  ConsumerState<SignatureQrView> createState() => _SignatureQrViewState();
}

class _SignatureQrViewState extends ConsumerState<SignatureQrView> {
  List<String>? _urParts;
  int? _urPartsBytes;
  bool _qrPaused = false;

  /// Pauses the animation and opens the tuning sheet; resumes when it closes.
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
      _urParts = encodeUrForQr(data: widget.signed, maxFragmentLength: settings.qrBytes);
      _urPartsBytes = settings.qrBytes;
    }
    final parts = _urParts!;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Signature', showBackButton: false),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              widget.instruction,
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
            if (parts.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Animated QR — keep both devices steady until the hot wallet finishes scanning.',
                style: text.caption.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }
}
