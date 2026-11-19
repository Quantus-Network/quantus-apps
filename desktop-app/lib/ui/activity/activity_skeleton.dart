import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Rows' shapes while their data is on its way: the icon, what and when, who
/// over its checkphrase, and the amount, a step lighter than the panel. They
/// breathe together, slowly, so the panel visibly works; with the system
/// asking for less motion they hold still.
///
/// A first load shows a day's heading and rows that fade out down the panel
/// ([fades]), reading as rows to come rather than a table of empty ones.
class ActivitySkeleton extends StatefulWidget {
  const ActivitySkeleton({super.key, this.rows = 5, this.fades = true, this.hasHeading = true});

  final int rows;
  final bool fades;
  final bool hasHeading;

  /// One breath, in and out.
  static const breath = Duration(milliseconds: 1600);

  @override
  State<ActivitySkeleton> createState() => _ActivitySkeletonState();
}

class _ActivitySkeletonState extends State<ActivitySkeleton> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: ActivitySkeleton.breath);

  /// Each row's who, so the rows are not all alike.
  static const _whoWidths = [300.0, 280.0, 300.0, 260.0, 290.0];
  static const _amountWidths = [70.0, 84.0, 60.0, 70.0, 76.0];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _breath
        ..stop()
        ..value = 0.5;
    } else if (!_breath.isAnimating) {
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _breath,
      builder: (context, _) {
        // In, then out, eased at both ends.
        final strength = 0.5 - 0.5 * math.cos(2 * math.pi * _breath.value);
        Widget bone(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: context.radiusV3.xsBorder,
            color: context.colorsV3.textContent.useOpacity(0.04 + 0.05 * strength),
          ),
        );

        return LayoutBuilder(
          builder: (context, constraints) {
            // Who shows only where a row would show it.
            final hasWho = constraints.maxWidth >= ActivityRowForm.tightFrom;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.hasHeading) Padding(padding: const EdgeInsets.fromLTRB(8, 18, 8, 10), child: bone(52, 10)),
                for (var i = 0; i < widget.rows; i++)
                  Opacity(
                    opacity: widget.fades ? 1 - i / (widget.rows + 0.5) : 1,
                    child: SizedBox(
                      height: 56,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            bone(28, 28),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [bone(76, 12), const SizedBox(height: 7), bone(44, 10)],
                            ),
                            if (hasWho) ...[
                              const SizedBox(width: 90),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, room) {
                                    final who = math.min(_whoWidths[i % _whoWidths.length], room.maxWidth);
                                    return Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [bone(who, 11), const SizedBox(height: 7), bone(who * 0.62, 11)],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                            ] else
                              const Spacer(),
                            bone(_amountWidths[i % _amountWidths.length], 12),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
