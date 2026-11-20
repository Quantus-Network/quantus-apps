import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// The approvals a multisig's proposal needs, and how many of them it has.
/// Up to [mostCircles] it is one circle for each, the first [approved] of
/// them filled. A multisig can need a hundred, more than a line holds: past
/// that it is one bar, filled by the share approved.
///
/// In less room than the circles take they are the bar too, and the bar is
/// no wider than the room, down to [leastBarWidth]; in less there are none.
///
/// What they count is said in words beside them, so a screen reader passes
/// them over.
class ApprovalMarks extends StatelessWidget {
  const ApprovalMarks({super.key, required this.approved, required this.needed});

  final int approved;
  final int needed;

  /// The most approvals drawn as a circle each.
  static const mostCircles = 10;

  static const barKey = Key('approval-marks-bar');
  static const barFillKey = Key('approval-marks-bar-fill');

  static const double _size = 10;
  static const double _gap = 5;

  static const double _barWidth = 96;
  static const double _barHeight = 4;

  /// The narrowest the bar is drawn; in less room there are no marks.
  static const double leastBarWidth = 24;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final room = constraints.maxWidth;
          if (needed <= mostCircles && needed * _size + (needed - 1) * _gap <= room) return _circles(context);
          if (room < leastBarWidth) return const SizedBox.shrink();
          return _bar(context, width: math.min(_barWidth, room));
        },
      ),
    );
  }

  Widget _circles(BuildContext context) {
    final colors = context.colorsV3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < needed; i++)
          Container(
            width: _size,
            height: _size,
            margin: EdgeInsets.only(left: i == 0 ? 0 : _gap),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < approved ? colors.semanticSage : null,
              border: Border.all(color: i < approved ? colors.semanticSage : colors.borderEmphasis, width: 1.5),
            ),
          ),
      ],
    );
  }

  Widget _bar(BuildContext context, {required double width}) {
    final colors = context.colorsV3;
    final radius = BorderRadius.circular(context.radiusV3.pill);
    // One approval of a hundred would be a sliver: it is at least a dot.
    final filled = approved <= 0 ? 0.0 : math.max(_barHeight, width * math.min(approved, needed) / needed);

    return Container(
      key: barKey,
      width: width,
      height: _barHeight,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(color: colors.borderEmphasis, borderRadius: radius),
      child: filled == 0
          ? null
          : Container(
              key: barFillKey,
              width: filled,
              height: _barHeight,
              decoration: BoxDecoration(color: colors.semanticSage, borderRadius: radius),
            ),
    );
  }
}
