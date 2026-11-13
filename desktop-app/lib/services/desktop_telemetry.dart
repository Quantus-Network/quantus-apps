import 'package:wallet_core/services/telemetry.dart';

/// Desktop telemetry has not been decided yet: the analytics SDK the mobile
/// app uses has no Windows or Linux implementation.
///
/// Every call throws, so the first desktop feature that reports telemetry
/// forces that decision instead of silently dropping its events.
class DesktopTelemetry implements Telemetry {
  const DesktopTelemetry();

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) =>
      throw UnimplementedError('Desktop telemetry is not implemented: cannot send the event "$eventName".');

  @override
  void sendError(String errorName, {required Object error}) =>
      throw UnimplementedError('Desktop telemetry is not implemented: cannot send the error "$errorName".');
}
