import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';

enum SegmentWidthMode {
  equal, // All segments have equal width (original behavior)
  fitContent, // Each segment fits its content
  custom, // Use custom widths defined per segment
}

class SegmentedControl<T> extends StatefulWidget {
  final List<SegmentedControlItem<T>> items;
  final T? selectedValue;
  final ValueChanged<T>? onSelectionChanged;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Duration animationDuration;
  final double height;
  final SegmentWidthMode widthMode;
  final double? minSegmentWidth;
  final double? maxSegmentWidth;

  const SegmentedControl({
    super.key,
    required this.items,
    this.selectedValue,
    this.onSelectionChanged,
    this.borderRadius = 100.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
    this.animationDuration = const Duration(milliseconds: 200),
    this.height = 52.0,
    this.widthMode = SegmentWidthMode.equal,
    this.minSegmentWidth,
    this.maxSegmentWidth,
  });

  @override
  State<SegmentedControl<T>> createState() => _SegmentedControlState<T>();
}

class _SegmentedControlState<T> extends State<SegmentedControl<T>> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  late Animation<double> _widthAnimation;
  int _selectedIndex = 0;
  int _previousIndex = 0;
  List<double> _segmentWidths = [];
  List<double> _segmentPositions = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: widget.animationDuration, vsync: this);

    // Find initial selected index
    _updateSelectedIndex();
    _previousIndex = _selectedIndex;

    // Initialize animations with current position and width
    _positionAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _widthAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  void _updateSelectedIndex() {
    if (widget.selectedValue != null) {
      final index = widget.items.indexWhere((item) => item.value == widget.selectedValue);
      if (index != -1) {
        _selectedIndex = index;
      }
    }
  }

  @override
  void didUpdateWidget(SegmentedControl<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedValue != widget.selectedValue) {
      _updateSelectedIndex();
      _animateToIndex(_selectedIndex);
    }
  }

  void _calculateSegmentDimensions(BoxConstraints constraints) {
    final availableWidth = constraints.maxWidth - widget.padding.horizontal;

    switch (widget.widthMode) {
      case SegmentWidthMode.equal:
        _calculateEqualWidths(availableWidth);
        break;
      case SegmentWidthMode.fitContent:
        _calculateFitContentWidths(availableWidth);
        break;
      case SegmentWidthMode.custom:
        _calculateCustomWidths(availableWidth);
        break;
    }

    _calculatePositions();
  }

  void _calculateEqualWidths(double availableWidth) {
    final segmentWidth = availableWidth / widget.items.length;
    _segmentWidths = List.filled(widget.items.length, segmentWidth);
  }

  void _calculateFitContentWidths(double availableWidth) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    List<double> contentWidths = [];
    double totalContentWidth = 0;

    // Calculate content width for each segment
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      double contentWidth = 0;

      if (item.child is Text) {
        final text = item.child as Text;
        textPainter.text = TextSpan(text: text.data, style: text.style ?? DefaultTextStyle.of(context).style);
        textPainter.layout();
        contentWidth = textPainter.width + 32; // Add padding
      } else {
        // For non-text widgets, estimate width or use custom width
        contentWidth = item.customWidth ?? 80;
      }

      // Apply min/max constraints if specified
      if (widget.minSegmentWidth != null) {
        contentWidth = contentWidth.clamp(widget.minSegmentWidth!, double.infinity);
      }
      if (widget.maxSegmentWidth != null) {
        contentWidth = contentWidth.clamp(0, widget.maxSegmentWidth!);
      }

      contentWidths.add(contentWidth);
      totalContentWidth += contentWidth;
    }

    // If total content width exceeds available width, scale down proportionally
    if (totalContentWidth > availableWidth) {
      final scaleFactor = availableWidth / totalContentWidth;
      _segmentWidths = contentWidths.map((width) => width * scaleFactor).toList();
    } else {
      // Distribute remaining space equally among segments
      final remainingSpace = availableWidth - totalContentWidth;
      final additionalSpace = remainingSpace / widget.items.length;
      _segmentWidths = contentWidths.map((width) => width + additionalSpace).toList();
    }
  }

  void _calculateCustomWidths(double availableWidth) {
    List<double> customWidths = [];
    double totalCustomWidth = 0;
    int flexibleSegments = 0;

    // First pass: collect custom widths and count flexible segments
    for (int i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      if (item.customWidth != null) {
        customWidths.add(item.customWidth!);
        totalCustomWidth += item.customWidth!;
      } else {
        customWidths.add(0); // Placeholder for flexible segments
        flexibleSegments++;
      }
    }

    // Calculate width for flexible segments
    final remainingWidth = availableWidth - totalCustomWidth;
    final double flexibleSegmentWidth = flexibleSegments > 0 ? remainingWidth / flexibleSegments : 0;

    // Second pass: assign final widths
    _segmentWidths = [];
    for (int i = 0; i < widget.items.length; i++) {
      if (widget.items[i].customWidth != null) {
        _segmentWidths.add(widget.items[i].customWidth!);
      } else {
        _segmentWidths.add(flexibleSegmentWidth);
      }
    }
  }

  void _calculatePositions() {
    _segmentPositions = [];
    double currentPosition = 0;

    for (int i = 0; i < _segmentWidths.length; i++) {
      _segmentPositions.add(currentPosition);
      currentPosition += _segmentWidths[i];
    }
  }

  void _animateToIndex(int newIndex) {
    if (newIndex != _previousIndex && _segmentPositions.isNotEmpty) {
      final previousPosition = _segmentPositions[_previousIndex];
      final newPosition = _segmentPositions[newIndex];
      final previousWidth = _segmentWidths[_previousIndex];
      final newWidth = _segmentWidths[newIndex];

      _positionAnimation = Tween<double>(
        begin: previousPosition,
        end: newPosition,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

      _widthAnimation = Tween<double>(
        begin: previousWidth,
        end: newWidth,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

      _animationController.reset();
      _animationController.forward();
      _previousIndex = newIndex;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTap(int index) {
    if (index != _selectedIndex) {
      setState(() {
        _selectedIndex = index;
      });
      _animateToIndex(index);
      widget.onSelectionChanged?.call(widget.items[index].value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.themeColors.darkGray;
    final selectedColor = context.themeColors.buttonNeutral;
    final selectedTextColor = context.themeColors.textSecondary;
    final unselectedTextColor = context.themeColors.textMuted;

    return LayoutBuilder(
      builder: (context, constraints) {
        _calculateSegmentDimensions(constraints);

        return Container(
          height: widget.height,
          decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(widget.borderRadius)),
          padding: widget.padding,
          child: Stack(
            children: [
              // Animated selected background
              if (_segmentPositions.isNotEmpty)
                AnimatedBuilder(
                  animation: Listenable.merge([_positionAnimation, _widthAnimation]),
                  builder: (context, child) {
                    final position = _segmentPositions.isNotEmpty
                        ? (_animationController.isAnimating
                              ? _positionAnimation.value
                              : _segmentPositions[_selectedIndex])
                        : 0.0;
                    final width = _segmentWidths.isNotEmpty
                        ? (_animationController.isAnimating ? _widthAnimation.value : _segmentWidths[_selectedIndex])
                        : 0.0;

                    return Positioned(
                      left: position,
                      top: 0,
                      bottom: 0,
                      width: width,
                      child: Container(
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(widget.borderRadius - 2),
                          boxShadow: [
                            BoxShadow(color: Colors.black.useOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // Segments
              Row(
                children: widget.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = index == _selectedIndex;
                  final segmentWidth = _segmentWidths.isNotEmpty && index < _segmentWidths.length
                      ? _segmentWidths[index]
                      : 0.0;

                  return SizedBox(
                    width: segmentWidth,
                    child: InkWell(
                      onTap: () => _onTap(index),
                      child: Container(
                        height: double.infinity,
                        alignment: Alignment.center,
                        child: AnimatedDefaultTextStyle(
                          duration: widget.animationDuration,
                          style: TextStyle(color: isSelected ? selectedTextColor : unselectedTextColor),
                          child: item.child,
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
    );
  }
}

class SegmentedControlItem<T> {
  final T value;
  final Widget child;
  final double? customWidth; // Custom width for this specific segment

  const SegmentedControlItem({required this.value, required this.child, this.customWidth});
}
