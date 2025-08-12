import 'package:telemetrydecksdk/telemetrydecksdk.dart';

/// Centralized Telemetry service to avoid scattering analytics code.
///
/// All features should call into this service instead of using
/// TelemetryDeck directly to keep the UI dumb and follow the DRY principle.
class TelemetryService {
  TelemetryService._internal();

  static final TelemetryService _instance = TelemetryService._internal();

  factory TelemetryService() => _instance;

  /// Sends a generic event signal.
  void sendEvent(String eventName, {Map<String, String>? parameters}) {
    Telemetrydecksdk.send(eventName, additionalPayload: parameters);
  }

  /// Tracks that a screen has been viewed.
  void trackScreenView(String screenName, {Map<String, String>? parameters}) {
    sendEvent(
      'screen_view',
      parameters: {'screen': screenName, if (parameters != null) ...parameters},
    );
  }
}
