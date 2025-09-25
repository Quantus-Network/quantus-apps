import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class Item<T> {
  final T value;
  final String label;

  Item({required this.value, required this.label});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Item && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class DropdownSelect<T> extends StatefulWidget {
  final List<Item<T>> items;
  final T? initialValue;
  final Function(Item<T>?)? onChanged;
  final double width;
  final bool disabled;

  const DropdownSelect({
    super.key,
    required this.items,
    this.initialValue,
    this.onChanged,
    this.width = 200,
    this.disabled = false,
  });

  @override
  State<DropdownSelect<T>> createState() => _DropdownSelectState<T>();
}

class _DropdownSelectState<T> extends State<DropdownSelect<T>> {
  Item<T>? selectedValue;
  bool isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    if (widget.initialValue != null) {
      selectedValue = widget.items.firstWhere(
        (item) => item.value == widget.initialValue,
        orElse: () => widget.items.first,
      );
    } else if (widget.items.isNotEmpty) {
      selectedValue = widget.items.first;
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleDropdown() {
    if (isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      isOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      isOpen = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    final validContext = context;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0.0, size.height + 2),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: validContext.themeColors.buttonNeutral,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.items.map((item) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedValue = item;
                      });
                      if (widget.onChanged != null) {
                        widget.onChanged!(item);
                      }
                      _closeDropdown();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        item.label,
                        style: validContext.themeText.smallParagraph?.copyWith(
                          color: selectedValue?.value == item.value
                              ? validContext.themeColors.pink
                              : validContext.themeColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: widget.disabled ? null : _toggleDropdown,
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: ShapeDecoration(
            color: widget.disabled
                ? Colors.grey.withValues(alpha: 0.50)
                : Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  selectedValue?.label ?? 'Select...',
                  style: context.themeText.smallParagraph,
                ),
              ),
              const SizedBox(width: 12),
              AnimatedRotation(
                turns: isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.themeColors.textPrimary,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
