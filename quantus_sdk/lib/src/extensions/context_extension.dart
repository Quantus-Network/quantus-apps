import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

extension SharePositionOriginExtension on BuildContext {
  Rect? sharePositionRect() {
    final box = findRenderObject() as RenderBox?;
    return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  }
}

extension DebugPrintExtension on BuildContext {
  void debugPrint(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}