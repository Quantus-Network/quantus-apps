import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Desktop sends no telemetry: the analytics SDK the mobile app uses has no
/// Windows or Linux implementation, and none has been chosen for desktop.
///
/// A call only names its event or error in the debug log, so nothing leaves
/// the machine. The text of an error is left out, as [Telemetry] requires.
class DesktopTelemetry implements Telemetry {
  const DesktopTelemetry();

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) =>
      quantusPrint('Telemetry event (not sent): $eventName');

  @override
  void sendError(String errorName, {required Object error}) => quantusPrint('Telemetry error (not sent): $errorName');
}
