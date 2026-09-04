import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// ADVANCED disclosure: collapsed by default so ordinary users never see what
/// it holds.
class AdvancedSection extends StatefulWidget {
  final List<Widget> children;

  const AdvancedSection({super.key, required this.children});

  @override
  State<AdvancedSection> createState() => _AdvancedSectionState();
}

class _AdvancedSectionState extends State<AdvancedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text('ADVANCED', style: text.labelMonogram.copyWith(color: colors.textMuted)),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
        if (_expanded) ...[const SizedBox(height: 12), ...widget.children],
      ],
    );
  }
}
