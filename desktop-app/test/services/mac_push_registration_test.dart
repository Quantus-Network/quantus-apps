import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_desktop_wallet/providers/notification_click_provider.dart';
import 'package:quantus_desktop_wallet/providers/notifications_provider.dart';
import 'package:quantus_desktop_wallet/services/mac_push.dart';
import 'package:quantus_desktop_wallet/services/mac_push_registration.dart';
import 'package:quantus_desktop_wallet/services/notification_plugin.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/notification_config_provider.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/remote_notifications_registration.dart';
import 'package:wallet_core/services/telemetry.dart';
import 'package:wallet_core/services/wallet_session.dart';

import '../fakes.dart';
import 'fake_mac_push.dart';
import 'fake_notification_plugin.dart';

class _RecordingTelemetry implements Telemetry {
  final errors = <String>[];

  @override
  void sendEvent(String eventName, {Map<String, String>? parameters}) {}

  @override
  void sendError(String errorName, {required Object error}) => errors.add(errorName);
}

class _RecordingClick extends NotificationClick {
  _RecordingClick(super.ref);

  final opened = <String?>[];

  @override
  void open(String? payload) => opened.add(payload);
}

/// Settings that take a multisig being added: the list in the app is what the
/// tests go by.
class _Settings extends FakeSettingsService {
  _Settings({super.activeAccount, super.multisigs});

  @override
  Future<void> addMultisigAccount(MultisigAccount account) async {}
}

const _remoteNotificationsOff = RemoteConfigModel(
  enableTestButtons: false,
  enableKeystoneHardwareWallet: true,
  enableHighSecurity: false,
  enableRemoteNotifications: false,
  enableEncryptedAccount: true,
  enableMultisig: true,
  enableOneClickNearWarning: true,
  geoNearAllowed: true,
);

/// What the app asked of Senoti: the method and path, and the body sent.
typedef _Asked = ({String what, Map<String, dynamic> body});

typedef _Mac = ({
  ProviderContainer container,
  FakeMacPush push,
  List<_Asked> senoti,
  _RecordingTelemetry telemetry,
  List<Account> accounts,
});

/// What Senoti answers; anything but 202 is a refusal.
var _senotiAnswers = 202;

/// When set, Senoti answers, and applies, a registration only once it
/// completes. What the test sees of Senoti is what it applied, in order.
Completer<void>? _holdRegistrations;

/// How many requests reached Senoti, applied or not yet.
var _senotiReached = 0;

/// A provider that was invalidated is only rebuilt once its zero-length
/// timer fires, which a pump without a duration never does.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(Duration.zero);
  }
}

/// What the app asked of Senoti, in order, each as `{what: body}`.
List<Map<String, Map<String, dynamic>>> _asked(_Mac mac) => [
  for (final asked in mac.senoti) {asked.what: asked.body},
];

/// A wallet of Main, Savings and an Encrypted account, with the Team
/// multisig, on a Mac whose notifications the person answered as [grants]
/// says. Nothing watches the registration unless [synced].
Future<_Mac> _open(
  WidgetTester tester, {
  bool grants = true,
  bool synced = false,
  List<Account> accounts = const [mainAccount, savingsAccount, encryptedAccount],
  List<MultisigAccount>? multisigs,
  RemoteConfigModel remoteConfig = RemoteConfigModel.defaults,
  FakeMacPush? push,
  Completer<void>? holdRegistrations,
  Map<String, bool> stored = const {},
  int senotiAnswers = 202,
}) async {
  SharedPreferences.setMockInitialValues({});
  _senotiAnswers = senotiAnswers;
  _holdRegistrations = holdRegistrations;
  _senotiReached = 0;
  final senoti = <_Asked>[];
  final telemetry = _RecordingTelemetry();
  final mac = push ?? FakeMacPush();
  final held = [...accounts];
  final container = ProviderContainer(
    overrides: [
      ...shellOverrides(
        loadAccounts: () async => [...held],
        settings: _Settings(activeAccount: const RegularAccount(mainAccount), multisigs: multisigs ?? [teamMultisig])
          ..bools.addAll(stored),
        remoteConfig: FakeRemoteConfigService(remoteConfig),
      ),
      notificationPluginProvider.overrideWithValue(FakeNotificationPlugin(grants: grants)),
      telemetryProvider.overrideWithValue(telemetry),
      macPushProvider.overrideWithValue(mac),
      notificationClickProvider.overrideWith(_RecordingClick.new),
      pushRegistrationProvider.overrideWith((ref) => ref.watch(macPushRegistrationProvider)),
      senotiClientProvider.overrideWithValue(
        SenotiAuthClient(
          'https://senoti.test/api',
          client: MockClient((request) async {
            _senotiReached++;
            if (request.method == 'POST') await _holdRegistrations?.future;
            senoti.add((
              what: '${request.method} ${request.url.path}',
              body: jsonDecode(request.body) as Map<String, dynamic>,
            ));
            return http.Response('', _senotiAnswers);
          }),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  container.listen(accountsProvider, (_, _) {});
  container.listen(multisigAccountsProvider, (_, _) {});
  await container.read(notificationConfigProvider.notifier).loaded;
  await container.read(desktopLocalNotificationsProvider.notifier).requestPermission();
  if (synced) container.listen(macPushSyncProvider, (_, _) {});
  await _settle(tester);
  expect(container.read(accountsProvider).hasValue, isTrue);
  expect(container.read(multisigAccountsProvider).hasValue, isTrue);
  return (container: container, push: mac, senoti: senoti, telemetry: telemetry, accounts: held);
}

void _test(String description, Future<void> Function(WidgetTester tester) body, {TargetPlatform? platform}) =>
    testWidgets(description, body, variant: TargetPlatformVariant.only(platform ?? TargetPlatform.macOS));

Future<void> _switchNotifications(_Mac mac, {required bool on}) {
  final config = mac.container.read(notificationConfigProvider);
  return mac.container.read(notificationConfigProvider.notifier).updateConfig(config.copyWith(enabled: on));
}

const _registeredKey = MacPushRegistration.registeredKey;

/// The account lists read again, as they are: the sync looks again.
void _accountsChanged(_Mac mac) => mac.container.invalidate(accountsProvider);

/// A reset as `LogoutService` runs one: the Mac is removed, unawaited, while
/// the wallet is wiped.
void _reset(_Mac mac) {
  final session = mac.container.read(walletSessionProvider)..beginReset();
  unawaited(mac.container.read(pushRegistrationProvider).unregister());
  session.finishReset();
}

const _removal = {
  'DELETE /api/devices': {'device_token': 'mac-token'},
};

const _registration = {
  'addresses': ['qzMain', 'qzSavings', 'qzTeam'],
  'device_token': 'mac-token',
  'platform': 'macos',
  'apns_environment': 'development',
};

void main() {
  group('MacPushRegistration', () {
    _test('registers the Mac\'s token, its Apple push service and the addresses that may be told of', (tester) async {
      final mac = await _open(tester);

      await mac.container.read(pushRegistrationProvider).registerDevice();

      expect(_asked(mac), [
        {'POST /api/devices': _registration},
      ]);
    });

    _test('never registers the address of an Encrypted account', (tester) async {
      final mac = await _open(tester, accounts: const [encryptedAccount], multisigs: const []);

      await mac.container.read(pushRegistrationProvider).registerDevice();

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0, reason: 'a wallet nothing may be told of asks Apple for nothing');
    });

    _test('registers nothing while macOS does not allow the app\'s notifications', (tester) async {
      final mac = await _open(tester, grants: false);

      await mac.container.read(pushRegistrationProvider).registerDevice();

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
    });

    _test('registers nothing while notifications are switched off in Settings', (tester) async {
      final mac = await _open(tester);
      await _switchNotifications(mac, on: false);

      await mac.container.read(pushRegistrationProvider).registerDevice();

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
    });

    _test('a build that was not signed to receive pushes registers nothing and removes nothing', (tester) async {
      final mac = await _open(tester, push: FakeMacPush(environmentOfBuild: null));

      await mac.container.read(pushRegistrationProvider).registerDevice();
      await mac.container.read(pushRegistrationProvider).unregister();

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
      expect(mac.telemetry.errors, isEmpty);
    });

    _test('a new address is left to the sync: adding an account never waits for Apple', (tester) async {
      final mac = await _open(tester);

      await mac.container.read(pushRegistrationProvider).registerAddress('qzNew');

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
    });

    _test('a reset removes the Mac, whatever its notifications are set to by then', (tester) async {
      final mac = await _open(tester);
      await _switchNotifications(mac, on: false);

      await mac.container.read(pushRegistrationProvider).unregister();

      expect(_asked(mac), [
        {
          'DELETE /api/devices': {'device_token': 'mac-token'},
        },
      ]);
    });

    _test('a reset while a registration is on its way removes the Mac after it, not before', (tester) async {
      final hold = Completer<void>();
      final mac = await _open(tester, holdRegistrations: hold);
      unawaited(mac.container.read(pushRegistrationProvider).registerDevice());
      await _settle(tester);
      expect(_senotiReached, 1, reason: 'the registration was sent');

      _reset(mac);
      await _settle(tester);
      expect(_senotiReached, 1, reason: 'the removal waits for the registration sent before it');
      hold.complete();
      await _settle(tester);

      expect(_asked(mac), [
        {'POST /api/devices': _registration},
        _removal,
      ]);
    });

    _test('a reset while a registration waits for Apple drops it: the wiped wallet is not registered', (tester) async {
      final push = FakeMacPush()..holdToken = Completer<void>();
      final mac = await _open(tester, push: push);
      unawaited(mac.container.read(pushRegistrationProvider).registerDevice());
      await _settle(tester);

      _reset(mac);
      push.holdToken!.complete();
      await _settle(tester);

      expect(_asked(mac), [_removal]);
    });

    _test('a registration asked for before a reset and run after it registers nothing', (tester) async {
      final push = FakeMacPush()..holdToken = Completer<void>();
      final mac = await _open(tester, push: push);
      final session = mac.container.read(walletSessionProvider)..beginReset();
      unawaited(mac.container.read(pushRegistrationProvider).unregister());
      // Asked by a flow of the wallet being wiped, as wallet creation asks.
      final registration = mac.container.read(pushRegistrationProvider).registerDevice();
      push.holdToken!.complete();
      session.finishReset();

      await registration;
      await _settle(tester);

      expect(_asked(mac), [_removal]);
    });

    _test('registers the token Apple gives now, not one it gave before', (tester) async {
      final mac = await _open(tester);
      await mac.container.read(pushRegistrationProvider).registerDevice();

      mac.push.token = 'mac-token-2';
      await mac.container.read(pushRegistrationProvider).registerDevice();

      expect(mac.senoti.map((asked) => asked.body['device_token']), ['mac-token', 'mac-token-2']);
    });

    _test('a token that cannot be had is reported and does not fail the account flow', (tester) async {
      final mac = await _open(tester);
      mac.push.tokenError = PlatformException(code: 'token-failed', message: 'no network');

      await expectLater(
        mac.container.read(pushRegistrationProvider).registerDevice(),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(registerForRemoteNotificationsBestEffort(mac.container.read), completes);

      expect(mac.senoti, isEmpty);
      expect(mac.telemetry.errors, ['registerForRemoteNotifications']);
    });

    _test('a removal that fails is reported and never thrown at the reset', (tester) async {
      final mac = await _open(tester);
      _senotiAnswers = 500;

      await expectLater(mac.container.read(pushRegistrationProvider).unregister(), completes);

      expect(mac.telemetry.errors, ['desktop_push_unregister_failed']);
    });
  });

  group('macPushSyncProvider', () {
    _test('registers the Mac once its notifications are allowed and its accounts are known', (tester) async {
      final mac = await _open(tester, synced: true);

      expect(_asked(mac), [
        {'POST /api/devices': _registration},
      ]);
    });

    _test('a reset while the sync\'s registration is on its way removes the Mac after it', (tester) async {
      final hold = Completer<void>();
      final mac = await _open(tester, synced: true, holdRegistrations: hold);
      expect(_senotiReached, 1, reason: 'the sync sent its registration');

      _reset(mac);
      await _settle(tester);
      hold.complete();
      await _settle(tester);

      expect(_asked(mac), [
        {'POST /api/devices': _registration},
        _removal,
      ]);
    });

    _test('a reset while the sync\'s registration waits for Apple drops it', (tester) async {
      final push = FakeMacPush()..holdToken = Completer<void>();
      final mac = await _open(tester, synced: true, push: push);

      _reset(mac);
      push.holdToken!.complete();
      await _settle(tester);

      expect(_asked(mac), [_removal]);
    });

    _test('registers nothing where remote notifications are switched off for everyone', (tester) async {
      final mac = await _open(tester, synced: true, remoteConfig: _remoteNotificationsOff);

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
    });

    _test('registers nothing while macOS does not allow the app\'s notifications', (tester) async {
      final mac = await _open(tester, synced: true, grants: false);

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
    });

    _test('removes the Mac when notifications are switched off, and registers it again when switched on', (
      tester,
    ) async {
      final mac = await _open(tester, synced: true);

      await _switchNotifications(mac, on: false);
      await _settle(tester);
      await _switchNotifications(mac, on: true);
      await _settle(tester);

      expect(mac.senoti.map((asked) => asked.what), ['POST /api/devices', 'DELETE /api/devices', 'POST /api/devices']);
    });

    _test('a removal that fails is tried again at the next change, until it goes through', (tester) async {
      final mac = await _open(tester, synced: true);
      _senotiAnswers = 500;
      await _switchNotifications(mac, on: false);
      await _settle(tester);

      _senotiAnswers = 202;
      _accountsChanged(mac);
      await _settle(tester);
      _accountsChanged(mac);
      await _settle(tester);

      expect(mac.senoti.map((asked) => asked.what), [
        'POST /api/devices',
        'DELETE /api/devices',
        'DELETE /api/devices',
      ]);
    });

    _test('a Mac an earlier run left registered is removed when the app starts with notifications off', (tester) async {
      final mac = await _open(tester, synced: true, grants: false, stored: {_registeredKey: true});

      expect(_asked(mac), [_removal]);
    });

    _test('a Mac that was never registered is not removed when the app starts with notifications off', (tester) async {
      final mac = await _open(tester, synced: true, grants: false);

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
    });

    _test('a registration that fails is tried again at the next change, though the addresses are the same', (
      tester,
    ) async {
      final push = FakeMacPush()..tokenError = PlatformException(code: 'token-failed', message: 'no network');
      final mac = await _open(tester, synced: true, push: push);
      expect(mac.senoti, isEmpty);

      push.tokenError = null;
      _accountsChanged(mac);
      await _settle(tester);
      _accountsChanged(mac);
      await _settle(tester);

      expect(_asked(mac), [
        {'POST /api/devices': _registration},
      ], reason: 'once registered, the same addresses are not sent again');
    });

    _test('a registration Senoti refuses is tried again at the next change', (tester) async {
      final mac = await _open(tester, synced: true, senotiAnswers: 500);
      expect(mac.senoti.map((asked) => asked.what), ['POST /api/devices']);
      _senotiAnswers = 202;

      _accountsChanged(mac);
      await _settle(tester);

      expect(mac.senoti.map((asked) => asked.what), ['POST /api/devices', 'POST /api/devices']);
    });

    _test('registers again when the wallet gains an account, and not when nothing changed', (tester) async {
      final mac = await _open(tester, synced: true);

      mac.container.invalidate(accountsProvider);
      await _settle(tester);
      expect(mac.senoti, hasLength(1), reason: 'the same accounts, read again');

      mac.accounts.add(const Account(walletIndex: 0, index: 2, name: 'Travel', accountId: 'qzTravel'));
      mac.container.invalidate(accountsProvider);
      await _settle(tester);

      expect(mac.senoti.map((asked) => asked.body['addresses']), [
        ['qzMain', 'qzSavings', 'qzTeam'],
        ['qzMain', 'qzSavings', 'qzTravel', 'qzTeam'],
      ]);
    });

    _test('registers again when a multisig joins the wallet', (tester) async {
      final mac = await _open(tester, synced: true, multisigs: const []);

      final added = await mac.container.read(multisigAccountsProvider.notifier).add(teamMultisig);
      await _settle(tester);

      expect(added, isTrue);
      expect(mac.senoti.map((asked) => asked.body['addresses']), [
        ['qzMain', 'qzSavings'],
        ['qzMain', 'qzSavings', 'qzTeam'],
      ]);
    });

    _test('a wallet restored after a reset is registered again, though its accounts are the same', (tester) async {
      final mac = await _open(tester, synced: true, multisigs: const []);
      final restored = [...mac.accounts];

      mac.accounts.clear();
      mac.container.invalidate(accountsProvider);
      await _settle(tester);
      mac.accounts.addAll(restored);
      mac.container.invalidate(accountsProvider);
      await _settle(tester);

      expect(mac.senoti.map((asked) => asked.body['addresses']), [
        ['qzMain', 'qzSavings'],
        ['qzMain', 'qzSavings'],
      ]);
    });

    _test('a click on a pushed notification opens what it was about', (tester) async {
      final mac = await _open(tester, synced: true);
      const payload = '{"accountId":"qzSavings","extrinsicHash":"0xabc"}';

      mac.push.click(payload);

      expect((mac.container.read(notificationClickProvider) as _RecordingClick).opened, [payload]);
    });

    _test('the click on a pushed notification that launched the app is opened too', (tester) async {
      const payload = '{"accountId":"qzMain","extrinsicHash":"0xdef"}';
      final mac = await _open(tester, synced: true, push: FakeMacPush(launchedBy: payload));

      expect((mac.container.read(notificationClickProvider) as _RecordingClick).opened, [payload]);
    });

    _test('on Windows nothing is registered and the Mac\'s side is never asked', (tester) async {
      final mac = await _open(tester, synced: true);

      expect(mac.senoti, isEmpty);
      expect(mac.push.tokenRequests, 0);
      expect(() => mac.push.click('{}'), throwsStateError, reason: 'nothing listens for a pushed click there');
    }, platform: TargetPlatform.windows);
  });
}
