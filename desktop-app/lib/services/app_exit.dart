import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Asks the system to close the app, as closing its only window does.
final requestAppExitProvider = Provider<VoidCallback>((ref) {
  return () => unawaited(ServicesBinding.instance.exitApplication(AppExitType.cancelable));
});
