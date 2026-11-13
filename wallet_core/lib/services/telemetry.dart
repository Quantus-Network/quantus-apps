import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/utils/unbound_seam.dart';

/// Where wallet_core reports analytics. Each app binds its own implementation
/// through `walletCoreOverrides`, because the analytics SDK is not available
/// on every platform.
abstract interface class Telemetry {
  /// Sends a generic event signal.
  void sendEvent(String eventName, {Map<String, String>? parameters});

  /// Sends an error signal tagged with [errorName]. Implementations must not
  /// forward the text of [error]: it can embed addresses, amounts or call data.
  void sendError(String errorName, {required Object error});
}

final telemetryProvider = Provider<Telemetry>((ref) => throw unboundSeam('telemetryProvider'));
