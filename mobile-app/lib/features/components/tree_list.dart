import 'package:flutter/material.dart';

// Data model for tree nodes
class TreeNode<T> {
  final T data;
  final List<TreeNode<T>> children;
  bool isExpanded;

  TreeNode({required this.data, this.children = const [], this.isExpanded = true});

  bool get hasChildren => children.isNotEmpty;
  bool get isLeaf => children.isEmpty;
}

// Tree structure list widget
class TreeListView<T> extends StatefulWidget {
  final List<TreeNode<T>> nodes;
  final Widget Function(BuildContext context, TreeNode<T> node, int depth) nodeBuilder;

  final bool showExpandCollapse;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const TreeListView({
    super.key,
    required this.nodes,
    required this.nodeBuilder,
    this.showExpandCollapse = true,
    this.padding,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  State<TreeListView<T>> createState() => _TreeListViewState<T>();
}

class _TreeListViewState<T> extends State<TreeListView<T>> {
  final Color lineColor = const Color(0x66FFFFFF);
  final double lineWidth = 1.0;
  final double indentWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: widget.padding,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      children: _buildTreeNodes(widget.nodes, 0, []),
    );
  }

  List<Widget> _buildTreeNodes(List<TreeNode<T>> nodes, int depth, List<bool> parentLines) {
    List<Widget> widgets = [];

    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final isLast = i == nodes.length - 1;
      final currentParentLines = List<bool>.from(parentLines)..add(!isLast);

      widgets.add(
        _TreeNodeWidget<T>(
          node: node,
          depth: depth,
          isLast: isLast,
          parentLines: parentLines,
          indentWidth: indentWidth,
          lineColor: lineColor,
          lineWidth: lineWidth,
          showExpandCollapse: widget.showExpandCollapse,
          nodeBuilder: widget.nodeBuilder,
          onToggleExpanded: () {
            setState(() {
              node.isExpanded = !node.isExpanded;
            });
          },
        ),
      );

      if (node.hasChildren && node.isExpanded) {
        widgets.addAll(_buildTreeNodes(node.children, depth + 1, currentParentLines));
      }
    }

    return widgets;
  }
}

class _TreeNodeWidget<T> extends StatelessWidget {
  final TreeNode<T> node;
  final int depth;
  final bool isLast;
  final List<bool> parentLines;
  final double indentWidth;
  final Color lineColor;
  final double lineWidth;
  final bool showExpandCollapse;
  final Widget Function(BuildContext context, TreeNode<T> node, int depth) nodeBuilder;
  final VoidCallback onToggleExpanded;

  const _TreeNodeWidget({
    required this.node,
    required this.depth,
    required this.isLast,
    required this.parentLines,
    required this.indentWidth,
    required this.lineColor,
    required this.lineWidth,
    required this.showExpandCollapse,
    required this.nodeBuilder,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Tree lines
        SizedBox(
          width: (depth + 1) * indentWidth,
          height: 56,
          child: CustomPaint(
            painter: TreeLinePainter(
              depth: depth,
              isLast: isLast,
              parentLines: parentLines,
              lineColor: lineColor,
              lineWidth: lineWidth,
              indentWidth: indentWidth,
            ),
          ),
        ),
        // Expand/collapse button
        if (showExpandCollapse && node.hasChildren)
          GestureDetector(
            onTap: onToggleExpanded,
            child: Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                border: Border.all(color: lineColor),
                color: Colors.white,
              ),
              child: Icon(node.isExpanded ? Icons.remove : Icons.add, size: 12, color: lineColor),
            ),
          )
        else if (showExpandCollapse)
          const SizedBox(width: 24),
        // Node content
        Expanded(child: nodeBuilder(context, node, depth)),
      ],
    );
  }
}

class TreeLinePainter extends CustomPainter {
  final int depth;
  final bool isLast;
  final List<bool> parentLines;
  final Color lineColor;
  final double lineWidth;
  final double indentWidth;

  TreeLinePainter({
    required this.depth,
    required this.isLast,
    required this.parentLines,
    required this.lineColor,
    required this.lineWidth,
    required this.indentWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Draw vertical lines for parent levels
    for (int i = 0; i < parentLines.length; i++) {
      if (parentLines[i]) {
        final x = (i + 1) * indentWidth - indentWidth / 2;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }

    if (depth >= 0) {
      final x = (depth + 1) * indentWidth - indentWidth / 2;
      final centerY = size.height / 2;

      // Draw vertical line (up to center or full height)
      if (!isLast) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      } else {
        canvas.drawLine(Offset(x, 0), Offset(x, centerY), paint);
      }

      // Draw horizontal line to the node (shorter to make room for arrow)
      final horizontalEndX = x + indentWidth / 2 - 6; // Leave space for arrow
      canvas.drawLine(Offset(x, centerY), Offset(horizontalEndX, centerY), paint);

      // Draw arrow at the end of horizontal line
      _drawArrow(canvas, paint, Offset(horizontalEndX, centerY));
    }
  }

  void _drawArrow(Canvas canvas, Paint paint, Offset position) {
    final arrowSize = 5.0;

    // Draw horizontal line for arrow shaft
    canvas.drawLine(Offset(position.dx, position.dy), Offset(position.dx + arrowSize, position.dy), paint);

    // Draw arrow head (two diagonal lines forming >)
    canvas.drawLine(
      Offset(position.dx + arrowSize, position.dy),
      Offset(position.dx + arrowSize - 2, position.dy - 2),
      paint,
    );
    canvas.drawLine(
      Offset(position.dx + arrowSize, position.dy),
      Offset(position.dx + arrowSize - 2, position.dy + 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Simple tree builder utility functions
List<TreeNode<T>> buildTreeFromMap<T>(Map<String, dynamic> data, T Function(String key, dynamic value) converter) {
  List<TreeNode<T>> nodes = [];

  data.forEach((key, value) {
    if (value is Map<String, dynamic>) {
      nodes.add(TreeNode(data: converter(key, value), children: buildTreeFromMap(value, converter)));
    } else if (value is List) {
      nodes.add(
        TreeNode(
          data: converter(key, value),
          children: value.map<TreeNode<T>>((item) => TreeNode(data: converter(item.toString(), item))).toList(),
        ),
      );
    } else {
      nodes.add(TreeNode(data: converter(key, value)));
    }
  });

  return nodes;
}

// File system item for demo
class FileSystemItem {
  final String name;
  final bool isDirectory;
  final String? extension;

  FileSystemItem({required this.name, required this.isDirectory, this.extension});

  IconData get icon {
    if (isDirectory) return Icons.folder;
    switch (extension?.toLowerCase()) {
      case 'dart':
        return Icons.code;
      case 'md':
        return Icons.description;
      case 'json':
        return Icons.data_object;
      case 'yaml':
      case 'yml':
        return Icons.settings;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get iconColor {
    if (isDirectory) return Colors.blue;
    switch (extension?.toLowerCase()) {
      case 'dart':
        return Colors.blue;
      case 'md':
        return Colors.orange;
      case 'json':
        return Colors.green;
      case 'yaml':
      case 'yml':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// Demo widget
class TreeListViewDemo extends StatelessWidget {
  const TreeListViewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final fileSystem = [
      TreeNode<FileSystemItem>(data: FileSystemItem(name: 'lib', isDirectory: true)),
      TreeNode<FileSystemItem>(data: FileSystemItem(name: 'assets', isDirectory: true)),
      TreeNode(
        data: FileSystemItem(name: 'pubspec.yaml', isDirectory: false, extension: 'yaml'),
      ),
      TreeNode(
        data: FileSystemItem(name: 'README.md', isDirectory: false, extension: 'md'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree Structure List'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File System Tree:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: TreeListView<FileSystemItem>(
                showExpandCollapse: false,
                nodes: fileSystem,
                nodeBuilder: (context, node, depth) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(node.data.icon, size: 18, color: node.data.iconColor),
                        const SizedBox(width: 8),
                        Text(
                          node.data.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: node.data.isDirectory ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
