import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/src/utils/print.dart';

class ToastRequest {
  const ToastRequest({required this.message, required this.iconData, required this.iconColor, required this.textColor});

  final String message;
  final IconData iconData;
  final Color iconColor;
  final Color textColor;
}

/// App-wide toast state, rendered by whichever [ToastHost]s are mounted.
class ToastController extends ValueNotifier<ToastRequest?> {
  ToastController._() : super(null);

  static final ToastController instance = ToastController._();

  int _hosts = 0;
  Timer? _timer;

  void registerHost() => _hosts++;

  void unregisterHost() => _hosts--;

  void show(ToastRequest request, Duration duration) {
    if (_hosts == 0) {
      quantusPrint('ToastController: no ToastHost mounted, dropped toast "${request.message}"');
      return;
    }

    _timer?.cancel();
    value = request;
    _timer = Timer(duration, dismiss);
  }

  void dismiss() {
    _timer?.cancel();
    value = null;
  }
}
