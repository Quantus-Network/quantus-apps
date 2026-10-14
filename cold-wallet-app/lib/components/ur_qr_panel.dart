import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/ur_qr_providers.dart';

/// An animated UR QR of [payload] with a frame progress bar, its
/// frame/FPS/bytes summary and, for multi-frame payloads, a pause button that
/// opens the tuning sheet. The frames and the paused flag live in providers,
/// so every screen that shows a QR behaves the same and keeps no QR state of
/// its own.
class UrQrPanel extends ConsumerStatefulWidget {
  final UrPayload payload;

  const UrQrPanel({super.key, required this.payload});

  @override
  ConsumerState<UrQrPanel> createState() => _UrQrPanelState();
}

class _UrQrPanelState extends ConsumerState<UrQrPanel> {
  int _frame = 0;

  @override
  void didUpdateWidget(UrQrPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.payload != oldWidget.payload) _frame = 0;
  }

  Future<void> _pauseAndTune() async {
    final paused = ref.read(qrPausedProvider.notifier);
    paused.pause();
    await BottomSheetContainer.show<void>(
      context,
      builder: (ctx) => const BottomSheetContainer(title: 'QR display options', child: QrTuningControls()),
    );
    paused.resume();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final settings = ref.watch(coldSettingsProvider);
    final parts = ref.watch(urQrFramesProvider(widget.payload));
    final paused = ref.watch(qrPausedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: AnimatedUrQr(
            parts: parts,
            fps: settings.qrFps,
            paused: paused,
            onFrameChanged: (frame) => setState(() => _frame = frame),
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: context.radiusV3.xsBorder,
          child: LinearProgressIndicator(
            value: ((_frame + 1) / parts.length).clamp(0.0, 1.0),
            minHeight: 4,
            backgroundColor: colors.bgSurface2,
            color: colors.accentFlare,
          ),
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
            if (parts.length > 1) ...[const SizedBox(width: 12), _PauseButton(onTap: _pauseAndTune)],
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

class _PauseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PauseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final bar = Container(
      width: 3,
      height: 12,
      decoration: BoxDecoration(color: colors.textContent, borderRadius: BorderRadius.circular(1.5)),
    );
    return Semantics(
      button: true,
      label: 'Pause and tune',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: colors.bgSurface2, shape: BoxShape.circle),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 3,
            children: [bar, bar],
          ),
        ),
      ),
    );
  }
}
