import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/serial_queue.dart';

void main() {
  test('steps run one at a time, in the order they were added', () async {
    final queue = SerialQueue();
    final first = Completer<void>();
    final log = <String>[];

    final a = queue.run(() async {
      log.add('a starts');
      await first.future;
      log.add('a ends');
    });
    final b = queue.run(() async => log.add('b'));
    await pumpEventQueue();

    expect(log, ['a starts']);

    first.complete();
    await Future.wait([a, b]);

    expect(log, ['a starts', 'a ends', 'b']);
  });

  test('a step\'s result reaches the one who added it', () async {
    final queue = SerialQueue();

    expect(await queue.run(() async => 42), 42);
  });

  test('a step that throws fails its own caller, and the next step still runs', () async {
    final queue = SerialQueue();

    final failing = queue.run<void>(() async => throw StateError('broken'));
    final next = queue.run(() async => 'ran');

    await expectLater(failing, throwsStateError);
    expect(await next, 'ran');
  });
}
