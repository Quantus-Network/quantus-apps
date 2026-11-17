import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One line of a terminal's report: `> NAME ....... [OK]`. The [status]
/// stands at the line's end, in sage unless given a [statusColor], with dot
/// leaders up to it; a line with none yet is its name alone, and a [isDim]
/// one is fainter, as a step not reached.
///
/// The name is drawn in capitals, which is a look: a screen reader gets it
/// as it is written.
class TerminalLine extends StatelessWidget {
  const TerminalLine({super.key, required this.name, this.status, this.statusColor, this.isDim = false});

  final String name;
  final String? status;
  final Color? statusColor;
  final bool isDim;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final status = this.status;
    final style = context.themeTextV3.dataAddressLarge.copyWith(
      height: 1,
      letterSpacing: 0.6,
      color: isDim ? colors.textMuted2 : colors.textMuted,
    );

    return Semantics(
      label: status == null ? name : '$name $status',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Text('> ${name.toUpperCase()}', style: style),
            const SizedBox(width: 8),
            Expanded(
              child: status == null
                  ? const SizedBox.shrink()
                  // Dot leaders up to the status, as many as fit.
                  : Text(
                      '.' * 200,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: style.copyWith(color: colors.textMuted2.useOpacity(0.5)),
                    ),
            ),
            if (status != null) ...[
              const SizedBox(width: 8),
              Text(status, style: style.copyWith(color: statusColor ?? colors.semanticSage)),
            ],
          ],
        ),
      ),
    );
  }
}
