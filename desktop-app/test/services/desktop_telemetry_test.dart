import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';

void main() {
  final notImplemented = throwsA(
    isA<UnimplementedError>().having((e) => e.message, 'message', contains('Desktop telemetry is not implemented')),
  );

  test('desktop telemetry is not implemented: sending an event or an error throws', () {
    const telemetry = DesktopTelemetry();

    expect(() => telemetry.sendEvent('send_transfer'), notImplemented);
    expect(() => telemetry.sendError('send_failed', error: StateError('boom')), notImplemented);
  });
}
