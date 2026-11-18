import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';

void main() {
  test('cancelPending drops the steps asked for so far that have not started, and later ones run', () async {
    final navigation = ShellNavigation();
    final waiting = Completer<void>();
    final log = <String>[];

    final first = navigation.run(() async {
      log.add('first');
      await waiting.future;
      navigation.cancelPending();
    });
    final dropped = navigation.run(() async => log.add('dropped'));
    await pumpEventQueue();
    waiting.complete();
    await Future.wait([first, dropped]);
    await navigation.run(() async => log.add('later'));

    expect(log, ['first', 'later']);
  });
}
