import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// One row in a [QuantusActionSheet].
///
/// Presentational only. Callers pass an already-resolved [label].
class QuantusActionSheetItem {
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const QuantusActionSheetItem({required this.label, required this.onTap, this.isDestructive = false});
}

/// Shared v3 kebab/action sheet: item list, ember destructive last, divider above it.
///
/// Presentational only. Overlay presentation is [showQuantusActionSheet].
class QuantusActionSheet extends StatelessWidget {
  final List<QuantusActionSheetItem> items;

  const QuantusActionSheet({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.lgBorder,
        border: Border.all(color: colors.borderEmphasis, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _ActionSheetItems(items: items),
          ),
        ),
      ),
    );
  }
}

/// Shows a [QuantusActionSheet] as a modal bottom sheet.
///
/// Tapping an item pops the sheet, then runs that item's [QuantusActionSheetItem.onTap].
/// Barrier tap or drag-down dismisses without running an action.
Future<void> showQuantusActionSheet(BuildContext context, {required List<QuantusActionSheetItem> items}) {
  return BottomSheetContainer.show<void>(
    context,
    builder: (sheetContext) {
      return QuantusActionSheet(
        items: [
          for (final item in items)
            QuantusActionSheetItem(
              label: item.label,
              isDestructive: item.isDestructive,
              onTap: () {
                Navigator.pop(sheetContext);
                item.onTap();
              },
            ),
        ],
      );
    },
  );
}

class _ActionSheetItems extends StatelessWidget {
  final List<QuantusActionSheetItem> items;

  const _ActionSheetItems({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (_isFirstDestructive(i)) const _ActionSheetDivider(),
          _ActionSheetRow(item: items[i]),
        ],
      ],
    );
  }

  bool _isFirstDestructive(int index) {
    if (!items[index].isDestructive) return false;
    return !items.take(index).any((item) => item.isDestructive);
  }
}

class _ActionSheetRow extends StatelessWidget {
  final QuantusActionSheetItem item;

  const _ActionSheetRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final color = item.isDestructive ? colors.semanticEmber : colors.textContent;

    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(item.label, style: context.themeTextV3.bodyEmphasis.copyWith(color: color)),
      ),
    );
  }
}

class _ActionSheetDivider extends StatelessWidget {
  const _ActionSheetDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(height: 1, thickness: 1, color: context.colorsV3.borderHairline),
    );
  }
}
