import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class SegmentedControls<T> extends StatelessWidget {
  final List<SegmentedControlItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  static const double _padding = 5.0;
  static const double _verticalPadding = 14.0;
  static const Duration _duration = Duration(milliseconds: 300);

  const SegmentedControls({super.key, required this.items, required this.selectedValue, required this.onChanged})
    : assert(items.length >= 2, 'SegmentedControls requires at least 2 items');

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final radius = context.radiusV3;
    final selectedIndex = items.indexWhere((item) => item.value == selectedValue);

    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: radius.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / items.length;
          final pillLeft = selectedIndex * segmentWidth;

          return SizedBox(
            height: _verticalPadding * 2 + 22,
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: _duration,
                  curve: Curves.easeInOut,
                  left: pillLeft,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: Container(
                    decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: radius.smBorder),
                  ),
                ),
                Row(
                  children: items.mapIndexed((index, item) {
                    final isSelected = index == selectedIndex;
                    return Expanded(
                      child: Semantics(
                        button: true,
                        selected: isSelected,
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
                                style: text.headingRow.copyWith(
                                  color: isSelected ? colors.textContent : colors.textMuted,
                                ),
                                child: Text(item.label, textAlign: TextAlign.center),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
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
