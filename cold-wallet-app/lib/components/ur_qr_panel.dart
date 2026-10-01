import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';

/// An animated UR QR of [payload] with its frame/FPS/bytes summary and, for
/// multi-frame payloads, a pause button that opens the tuning sheet. The
/// frames and the paused flag live in providers, so every screen that shows
/// a QR behaves the same and keeps no QR state of its own.
class UrQrPanel extends ConsumerWidget {
  final UrPayload payload;

  const UrQrPanel({super.key, required this.payload});

  Future<void> _pauseAndTune(BuildContext context, WidgetRef ref) async {
    final paused = ref.read(qrPausedProvider.notifier);
    paused.pause();
    await BottomSheetContainer.show<void>(
      context,
      builder: (ctx) => const BottomSheetContainer(title: 'QR display options', child: QrTuningControls()),
    );
    paused.resume();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final settings = ref.watch(coldSettingsProvider);
    final parts = ref.watch(urQrFramesProvider(payload));
    final paused = ref.watch(qrPausedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: AnimatedUrQr(parts: parts, fps: settings.qrFps, paused: paused),
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
                onTap: () => _pauseAndTune(context, ref),
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
            'Animated QR — keep both devices steady until the other device finishes scanning.',
            style: text.caption.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
