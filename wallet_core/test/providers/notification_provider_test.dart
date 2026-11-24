import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/providers/notification_provider.dart';

import '../fakes.dart';

const _defaults = NotificationConfig(
  enabled: true,
  sound: true,
  vibration: true,
  showBadge: true,
  sentTokensEnabled: true,
  receivedTokensEnabled: true,
  recoveryTimerEndingEnabled: true,
  reversibleTransactionsEnabled: true,
);

NotificationData _note(
  String id, {
  NotificationSource source = NotificationSource.push,
  NotificationIntent intent = NotificationIntent.sentTokens,
  DateTime? scheduledTime,
}) => NotificationData(
  id: id,
  accountId: 'account',
  type: NotificationType.info,
  intent: intent,
  source: source,
  title: 'Title',
  message: 'Message',
  accountName: 'Account',
  timestamp: DateTime(2026),
  scheduledTime: scheduledTime,
  persistent: true,
);

/// A launch with [saved] on disk and the preferences already in memory, as
/// they are by the time a running app raises its first notification.
Future<void> _launchWith(NotificationConfig saved) async {
  SharedPreferences.setMockInitialValues({notificationConfigKey: jsonEncode(saved.toJson())});
  await SharedPreferences.getInstance();
}

Iterable<String> _listed(ProviderContainer container) => container.read(notificationProvider).map((n) => n.id);

Future<List<Object?>> _stored() async {
  final saved = (await SharedPreferences.getInstance()).getStringList(notificationsStorageKey) ?? [];
  return saved.map((json) => jsonDecode(json)['id']).toList();
}

void main() {
  late WalletTestBed bed;
  late ProviderContainer container;

  void start() {
    bed = WalletTestBed();
    container = ProviderContainer(overrides: bed.overrides);
    addTearDown(container.dispose);
  }

  Future<void> add(NotificationData notification) =>
      container.read(notificationProvider.notifier).addNotification(notification);

  group('the first notification after launch, with saved settings', () {
    test('a push is shown, listed and stored', () async {
      await _launchWith(_defaults.copyWith(sound: false));
      start();

      await add(_note('first'));

      expect(bed.localNotifications.shown.map((n) => n.id), ['first']);
      expect(_listed(container), ['first']);
      expect(await _stored(), ['first']);
    });

    test('a local one is listed and stored, and not handed to the system', () async {
      await _launchWith(_defaults.copyWith(sound: false));
      start();

      await add(_note('first', source: NotificationSource.local));

      expect(bed.localNotifications.shown, isEmpty);
      expect(_listed(container), ['first']);
      expect(await _stored(), ['first']);
    });

    test('with notifications saved as off, nothing is shown, listed or stored', () async {
      await _launchWith(_defaults.copyWith(enabled: false));
      start();

      await add(_note('first'));

      expect(bed.localNotifications.shown, isEmpty);
      expect(_listed(container), isEmpty);
      expect(await _stored(), isEmpty);
    });

    test('with its type saved as off, only that type is held back', () async {
      await _launchWith(_defaults.copyWith(sentTokensEnabled: false));
      start();

      await add(_note('sent'));
      await add(_note('received', intent: NotificationIntent.receivedTokens));

      expect(bed.localNotifications.shown.map((n) => n.id), ['received']);
      expect(_listed(container), ['received']);
      expect(await _stored(), ['received']);
    });
  });

  test('a setting changed while running applies to the next notification', () async {
    await _launchWith(_defaults);
    start();
    final config = container.read(notificationConfigProvider.notifier);

    await add(_note('before'));
    await config.updateConfig(_defaults.copyWith(enabled: false));
    await add(_note('while off'));
    await config.updateConfig(_defaults);
    await add(_note('after'));

    expect(bed.localNotifications.shown.map((n) => n.id), ['before', 'after']);
    expect(_listed(container), ['before', 'after']);
    expect(await _stored(), ['before', 'after']);
  });

  test('a notifier replaced while it is adding drops the notification, without a crash', () async {
    await _launchWith(_defaults);
    start();

    final adding = add(_note('first'));
    container.invalidate(notificationProvider);
    await adding;

    expect(bed.localNotifications.shown, isEmpty);
    expect(_listed(container), isEmpty);
    expect(await _stored(), isEmpty);
  });

  for (final (what, switchedOff) in [
    ('notifications are', _defaults.copyWith(enabled: false)),
    ('its type is', _defaults.copyWith(reversibleTransactionsEnabled: false)),
  ]) {
    testWidgets('a reminder waiting when $what switched off is not added when it fires', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final bed = WalletTestBed();
      final container = ProviderContainer(overrides: bed.overrides);
      final notifications = container.read(notificationProvider.notifier);
      await tester.pump();
      await notifications.addNotification(
        _note(
          'reminder',
          source: NotificationSource.local,
          intent: NotificationIntent.reversibleTransactions,
          scheduledTime: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      await container.read(notificationConfigProvider.notifier).updateConfig(switchedOff);
      await tester.pump(const Duration(hours: 2));

      expect(tester.takeException(), isNull);
      expect(container.read(notificationProvider), isEmpty);
      container.dispose();
    });
  }
}
