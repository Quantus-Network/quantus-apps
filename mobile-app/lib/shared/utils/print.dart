import 'package:flutter/foundation.dart';

void quantusDebugPrint(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}
