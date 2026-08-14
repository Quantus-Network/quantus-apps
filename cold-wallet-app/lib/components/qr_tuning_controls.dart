import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// FPS and bytes-per-frame sliders bound to [coldSettingsProvider], shared by
/// the settings screen and the signature view so tuning behaves identically.
class QrTuningControls extends ConsumerWidget {
  const QrTuningControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(coldSettingsProvider);
    final controller = ref.read(coldSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TuningSlider(
          label: 'Frame rate',
          valueText: '${settings.qrFps} FPS',
          value: settings.qrFps.toDouble(),
          min: ColdSettings.minQrFps.toDouble(),
          max: ColdSettings.maxQrFps.toDouble(),
          divisions: ColdSettings.maxQrFps - ColdSettings.minQrFps,
          onChanged: (v) => controller.setQrFps(v.round()),
        ),
        const SizedBox(height: 8),
        _TuningSlider(
          label: 'Bytes per frame',
          valueText: '${settings.qrBytes} bytes',
          value: settings.qrBytes.toDouble(),
          min: ColdSettings.minQrBytes.toDouble(),
          max: ColdSettings.maxQrBytes.toDouble(),
          divisions: (ColdSettings.maxQrBytes - ColdSettings.minQrBytes) ~/ 25,
          onChanged: (v) => controller.setQrBytes(v.round()),
        ),
      ],
    );
  }
}

class _TuningSlider extends StatelessWidget {
  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  const _TuningSlider({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: text.detail?.copyWith(color: colors.textSecondary)),
            Text(valueText, style: text.detail?.copyWith(color: colors.textPrimary)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: colors.accentOrange,
            inactiveTrackColor: colors.borderButton,
            thumbColor: colors.accentOrange,
            overlayColor: colors.accentOrange.withValues(alpha: 0.15),
            trackHeight: 2,
          ),
          child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
        ),
      ],
    );
  }
}
