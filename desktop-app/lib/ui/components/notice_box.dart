import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// A note set apart from what is around it: a box tinted and edged in
/// [tone], with a [symbol] in that colour before the note when one is given.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.tone, this.symbol, required this.child});

  final Color tone;
  final IconData? symbol;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.useOpacity(0.08),
        borderRadius: context.radiusV3.smBorder,
        border: Border.all(color: tone.useOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (symbol != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(symbol, size: 13, color: tone),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}
