import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The scanner's status strip: hint, frame counter, progress and frame map.
class QrScanHud extends StatelessWidget {
  static const int missingShown = 20;

  final QrScanOverlayModel model;
  final QrScanStrings strings;
  final Animation<double> flash;
  final bool showFrameMap;

  const QrScanHud({
    super.key,
    required this.model,
    required this.strings,
    required this.flash,
    this.showFrameMap = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final child = switch (model.phase) {
          QrScanPhase.error => Text(strings.errorHint, style: text.caption.copyWith(color: colors.semanticEmber)),
          QrScanPhase.complete => Text(
            strings.completeLabel,
            style: text.labelData.copyWith(color: colors.semanticSage),
          ),
          _ when model.partCount == 0 => Text(strings.idleHint, style: text.caption.copyWith(color: colors.textMuted)),
          _ => _progress(context),
        };
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Container(
            key: ValueKey(
              model.phase == QrScanPhase.error || model.phase == QrScanPhase.complete || model.partCount == 0,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors.bgVoid.useOpacity(0.6), borderRadius: context.radiusV3.smBorder),
            child: child,
          ),
        );
      },
    );
  }

  Widget _progress(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final expected = model.expected;
    final counter = expected == null
        ? strings.scanning(model.partCount)
        : strings.progress(model.seen.length, expected);
    final missing = model.missingIndexes.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(strings.collectingLabel, style: text.labelMonogram.copyWith(color: colors.textMuted)),
            Text(counter, style: text.labelData.copyWith(color: colors.textContent)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: context.radiusV3.xsBorder,
          child: LinearProgressIndicator(
            value: model.progress,
            minHeight: 4,
            backgroundColor: colors.bgSurface2,
            color: colors.accentFlare,
          ),
        ),
        if (showFrameMap && expected != null) ...[
          const SizedBox(height: 8),
          QrFrameMap(expected: expected, seen: model.seen, lastAdded: model.lastAddedIndex, flash: flash),
        ],
        if (model.stalled && missing.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(strings.stallHint, style: text.caption.copyWith(color: colors.semanticSand)),
          Text(
            strings.missingFrames(
              missing.take(missingShown).toList(),
              (missing.length - missingShown).clamp(0, missing.length),
            ),
            style: text.caption.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}
