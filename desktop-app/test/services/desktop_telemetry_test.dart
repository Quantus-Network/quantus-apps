import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/desktop_telemetry.dart';

/// What [body] writes to the log.
List<String> _logged(void Function() body) {
  final lines = <String>[];
  runZoned(body, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => lines.add(line)));
  return lines;
}

void main() {
  const telemetry = DesktopTelemetry();

  test('desktop telemetry sends nothing: an event is only named in the log', () {
    expect(_logged(() => telemetry.sendEvent('send_transfer', parameters: {'kind': 'private'})), [
      'Telemetry event (not sent): send_transfer',
    ]);
  });

  test('an error is only named in the log, without the text of the error itself', () {
    expect(_logged(() => telemetry.sendError('send_failed', error: StateError('to qzSecretAddress'))), [
      'Telemetry error (not sent): send_failed',
    ]);
  });
}
