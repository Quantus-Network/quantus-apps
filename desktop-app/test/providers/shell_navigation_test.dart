import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/open_wallets_provider.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';

void main() {
  test('cancelPending drops the steps asked for so far that have not started, and later ones run', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final navigation = container.read(shellNavigationProvider.notifier);
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

  test('with no accounts showing, the sidebar does not move', () async {
    final container = ProviderContainer(overrides: [visibleSidebarAccountsProvider.overrideWithValue(const [])]);
    addTearDown(container.dispose);
    final navigator = container.read(sidebarNavigatorProvider);

    await navigator.move(1);
    await navigator.move(-1);

    expect(container.read(accountSwitchFailureProvider), isNull);
  });
}
