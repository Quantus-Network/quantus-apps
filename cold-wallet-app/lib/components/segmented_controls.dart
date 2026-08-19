import 'package:flutter/material.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// A pill segmented control: the same one the hot wallet uses, down to the
/// colour tokens, so the two apps read as one product.
class SegmentedControls<T> extends StatelessWidget {
  final List<SegmentedControlItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  static const double _padding = 5.0;
  static const double _outerRadius = 10.5;
  static const double _pillRadius = 8.0;
  static const double _height = 44.0;
  static const Duration _duration = Duration(milliseconds: 250);

  const SegmentedControls({super.key, required this.items, required this.selectedValue, required this.onChanged})
    : assert(items.length >= 2, 'SegmentedControls requires at least 2 items');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final selectedIndex = items.indexWhere((item) => item.value == selectedValue);

    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(_outerRadius),
        border: Border.all(color: colors.txItemBorderDefault, width: 1.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / items.length;

          return SizedBox(
            height: _height,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: _duration,
                  curve: Curves.easeInOut,
                  left: selectedIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.segmentedControlPill,
                      borderRadius: BorderRadius.circular(_pillRadius),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (index, item) in items.indexed)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: index == selectedIndex,
                          label: item.label,
                          child: GestureDetector(
                            onTap: () => onChanged(item.value),
                            behavior: HitTestBehavior.opaque,
                            child: SizedBox(
                              height: double.infinity,
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: _duration,
                                  curve: Curves.easeInOut,
                                  style: (text.smallParagraph ?? const TextStyle(fontSize: 16)).copyWith(
                                    color: index == selectedIndex ? colors.textPrimary : colors.textSecondary,
                                  ),
                                  child: Text(item.label, textAlign: TextAlign.center),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SegmentedControlItem<T> {
  final T value;
  final String label;

  const SegmentedControlItem({required this.value, required this.label});
}
