import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/ui/activity/activity_row_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Rows' shapes while their data is on its way, a step lighter than the
/// panel. They breathe together, slowly, so the panel visibly works; with the
/// system asking for less motion they hold still.
///
/// A first load ([rows] null) fills the space it is given as activity would:
/// days under their headings, of different sizes, down to within a row of
/// its end. Each row is shaped as a real one with an address at that width
/// ([ActivityRowForm]): as tall, its bars where the words go, and the
/// address over its checkphrase where they go. Loading more shows [rows]
/// rows, under no heading.
class ActivitySkeleton extends StatefulWidget {
  const ActivitySkeleton({super.key, this.rows});

  /// How many rows, as at the list's end while more loads; null fills the
  /// space with days of rows.
  final int? rows;

  /// One breath, in and out.
  static const breath = Duration(milliseconds: 1600);

  static Key headingKey(int day) => ValueKey(('activity-skeleton-heading', day));
  static Key rowKey(int index) => ValueKey(('activity-skeleton-row', index));
  static Key whoKey(int index) => ValueKey(('activity-skeleton-who', index));

  /// How many rows each day has, so that its headings and rows fill [height]
  /// to within one row, as activity would: days of 2, 3, 1 and 4 rows in
  /// turn. A day starts only where its heading and a row fit; the room left
  /// after that goes to the last day's rows. Nothing fits, no day.
  static List<int> daysFor({
    required double height,
    required double rowHeight,
    required double firstHeadingHeight,
    required double headingHeight,
  }) {
    const sizes = [2, 3, 1, 4];
    final days = <int>[];
    var used = 0.0;
    while (true) {
      final heading = days.isEmpty ? firstHeadingHeight : headingHeight;
      if (used + heading + rowHeight > height) break;
      used += heading;
      final size = sizes[days.length % sizes.length];
      var rows = 0;
      while (rows < size && used + rowHeight <= height) {
        rows++;
        used += rowHeight;
      }
      days.add(rows);
      if (rows < size) return days;
    }
    while (days.isNotEmpty && used + rowHeight <= height) {
      days[days.length - 1]++;
      used += rowHeight;
    }
    return days;
  }

  @override
  State<ActivitySkeleton> createState() => _ActivitySkeletonState();
}

class _ActivitySkeletonState extends State<ActivitySkeleton> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: ActivitySkeleton.breath);

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
        final shapes = _Shapes(context, context.colorsV3.textContent.useOpacity(0.04 + 0.05 * strength));

        return LayoutBuilder(
          builder: (context, constraints) {
            final rows = widget.rows;
            if (rows != null) {
              final form = ActivityRowForm.of(constraints.maxWidth);
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (var i = 0; i < rows; i++) shapes.row(i, form)],
              );
            }
            if (!constraints.hasBoundedHeight) {
              throw FlutterError("A first load's ActivitySkeleton fills its height, so it needs a bounded one.");
            }
            // 8 in from the panel's sides, as the list's rows are.
            final form = ActivityRowForm.of(constraints.maxWidth - 16);
            final days = ActivitySkeleton.daysFor(
              height: constraints.maxHeight,
              rowHeight: shapes.rowHeight(form),
              firstHeadingHeight: shapes.headingHeight(first: true),
              headingHeight: shapes.headingHeight(first: false),
            );
            var index = 0;
            return ListView(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final (day, size) in days.indexed) ...[
                  shapes.heading(day),
                  for (var i = 0; i < size; i++) shapes.row(index++, form),
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// The shapes of a day's heading and of rows, measured from the real ones'
/// type, in one breath's [colour].
class _Shapes {
  _Shapes(this.context, this.colour);

  final BuildContext context;
  final Color colour;

  /// Each row's who and amount, and each day's heading, so they are not all
  /// alike.
  static const _whoWidths = [300.0, 280.0, 300.0, 260.0, 290.0];
  static const _amountWidths = [70.0, 84.0, 60.0, 70.0, 76.0];
  static const _headingWidths = [52.0, 72.0, 88.0, 64.0];

  AppTextThemeV3 get _text => context.themeTextV3;
  TextStyle get _address => _text.dataAddress.copyWith(height: 1.3, letterSpacing: 0.3);
  TextStyle get _heading => _text.caption.copyWith(fontWeight: FontWeight.w500, letterSpacing: 0.8);

  /// How tall a line of [style] is, as the real words take it.
  double _line(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: 'Hg', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  /// An address over its checkphrase, as [AddressCheckphrase] stacks them.
  double get _whoHeight => _line(_address) * 2 + 4;

  /// A real row's height in [form], with an address.
  double rowHeight(ActivityRowForm form) => switch (form) {
    ActivityRowForm.wide => math.max(
      56,
      12 +
          [
            28.0,
            _line(_text.bodyEmphasis) + 4 + _line(_text.caption),
            _whoHeight,
            _line(_text.amountRow),
          ].reduce(math.max),
    ),
    ActivityRowForm.tight => 10 + 28 + 2 + _whoHeight + 10,
    ActivityRowForm.brief => 52,
  };

  /// A day's heading's height, as the list spaces it.
  double headingHeight({required bool first}) => (first ? 14 : 20) + _line(_heading) + 6;

  Widget _bone(double width, double height) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(borderRadius: context.radiusV3.xsBorder, color: colour),
  );

  /// A bar of [width] standing for a line of [style].
  Widget _bar(double width, double height, TextStyle style) => SizedBox(
    width: width,
    height: _line(style),
    child: Align(alignment: Alignment.centerLeft, child: _bone(width, height)),
  );

  Widget heading(int day) => Padding(
    key: ActivitySkeleton.headingKey(day),
    padding: EdgeInsets.fromLTRB(8, day == 0 ? 14 : 20, 8, 6),
    child: Align(alignment: Alignment.centerLeft, child: _bar(_headingWidths[day % 4], 10, _heading)),
  );

  Widget _what() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_bar(76, 12, _text.bodyEmphasis), const SizedBox(height: 4), _bar(44, 10, _text.caption)],
  );

  Widget _who(int index) => LayoutBuilder(
    builder: (context, room) {
      final width = math.min(_whoWidths[index % 5], room.maxWidth);
      return Column(
        key: ActivitySkeleton.whoKey(index),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_bar(width, 11, _address), const SizedBox(height: 4), _bar(width * 0.62, 11, _address)],
      );
    },
  );

  Widget _amount(int index) => _bar(_amountWidths[index % 5], 12, _text.amountRow);

  /// Row [index]'s shapes, laid out as a real row in [form] is.
  Widget row(int index, ActivityRowForm form) => SizedBox(
    key: ActivitySkeleton.rowKey(index),
    height: rowHeight(form),
    child: switch (form) {
      ActivityRowForm.wide => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            _bone(28, 28),
            const SizedBox(width: 12),
            SizedBox(width: ActivityRowView.whatWidth, child: _what()),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  const SizedBox(width: ActivityRowView.prefixWidth),
                  Flexible(child: _who(index)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _amount(index),
          ],
        ),
      ),
      ActivityRowForm.tight => Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bone(28, 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 28,
                    child: Row(
                      children: [
                        _bar(76, 12, _text.bodyEmphasis),
                        const SizedBox(width: 8),
                        _bar(44, 10, _text.caption),
                        const Spacer(),
                        const SizedBox(width: 12),
                        _amount(index),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: ActivityRowView.tightPrefixWidth),
                      Flexible(child: _who(index)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ActivityRowForm.brief => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            _bone(28, 28),
            const SizedBox(width: 12),
            Expanded(child: _what()),
            const SizedBox(width: 12),
            _amount(index),
          ],
        ),
      ),
    },
  );
}
