import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/one_click_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/remote_config_service.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';
import 'package:resonance_network_wallet/v2/screens/send/encrypted_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/select_recipient_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes.dart';

const _account = Account(walletIndex: 0, index: 0, name: 'Encrypted', accountId: 'qzSELF');
const _derivedAddress = 'qzDERIVED';
const _depositAddress = 'qznt5jvuXdh4ZMnTPDnHo4Xq3KwjZPDRqwmd4AW3nDGmuEACG';
const _plainAddress = 'qzmTAz3UUw1WGUuVh8nbFmPwcftomduwy6twq6NDR6y9qqtEs';
const _unreachableAddress = 'qzUNREACHABLE';

/// Lets the warning toast a refusal raises expire before the tree is torn down.
const _toastLifetime = Duration(seconds: 3);

final _configWithKey = RemoteConfigModel.fromJson(const {'near.partner.jwt': 'partner-jwt'});
final _configWithoutKey = RemoteConfigModel.fromJson(const {});
final _configCheckOff = RemoteConfigModel.fromJson(const {
  'near.partner.jwt': 'partner-jwt',
  'enableOneClickNearWarning': false,
});

class _FakeEncryptedAccountService extends Fake implements EncryptedAccountService {
  @override
  Future<bool> ownsAddress(String address) async => address == _derivedAddress;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final lookedUp = <String>[];

  /// 1Click as the guard sees it: history for [_depositAddress], none for any
  /// other address, and no answer at all for [_unreachableAddress]. Built per
  /// test, since the service remembers every answer.
  late OneClickService oneClick;

  setUp(() async {
    lookedUp.clear();
    oneClick = OneClickService(
      apiKey: 'partner-jwt',
      client: MockClient((request) async {
        final address = request.url.queryParameters['depositAddress']!;
        lookedUp.add(address);
        if (address == _unreachableAddress) throw http.ClientException('connection refused');
        final items = address == _depositAddress
            ? [
                {'depositAddress': address},
              ]
            : [];
        return http.Response(jsonEncode({'items': items}), 200);
      }),
    );
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  /// [remoteConfig] defaults to a config that already carries the partner key.
  /// Without [withOneClick] the real client is built from that config, so a
  /// missing key refuses the lookup before any request.
  Future<void> pumpRecipient(
    WidgetTester tester,
    SendStrategy strategy, {
    RemoteConfigService? remoteConfig,
    bool withOneClick = true,
  }) async {
    final config = remoteConfig ?? FakeRemoteConfigService(_configWithKey, remote: _configWithKey);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          humanReadableChecksumServiceProvider.overrideWithValue(FakeHumanReadableChecksumService()),
          substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
          recentAddressesServiceProvider.overrideWithValue(FakeRecentAddressesService()),
          encryptedAccountServiceProvider.overrideWith((ref, walletIndex) => _FakeEncryptedAccountService()),
          remoteConfigProvider.overrideWith((ref) => RemoteConfigNotifier(config)),
          if (withOneClick) oneClickServiceProvider.overrideWithValue(oneClick),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(800, 900)),
          child: Builder(
            builder: (context) => MaterialApp(
              theme: AppTheme.darkTheme(context),
              home: SelectRecipientScreen(strategy: strategy),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> enterRecipient(WidgetTester tester, String address) async {
    await tester.enterText(find.byKey(const Key(E2EKeys.sendRecipientField)), address);
    await tester.pump();
    await tester.pump();
  }

  void expectContinue(WidgetTester tester, {required bool disabled, required String label}) {
    final button = find.byKey(const Key(E2EKeys.sendContinueButton));
    expect(tester.widget<QuantusButton>(button).isDisabled, disabled);
    expect(find.descendant(of: button, matching: find.text(label)), findsOneWidget);
  }

  group('encrypted send recipient guard', () {
    const strategy = EncryptedSendStrategy(account: _account);

    testWidgets('a 1Click deposit address shows the warning and disables continue', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _depositAddress);

      expect(find.text('NEAR Intents address detected'), findsOneWidget);
      expect(find.textContaining('Use a transparent account'), findsOneWidget);
      expect(find.text('Private Send'), findsNothing);
      expectContinue(tester, disabled: true, label: "Can't Send to NEAR Intents");
      expect(lookedUp, [_depositAddress]);
    });

    testWidgets('any other address keeps the private-send notice and continue enabled', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _plainAddress);

      expect(find.text('NEAR Intents address detected'), findsNothing);
      expect(find.text('Private Send'), findsOneWidget);
      expectContinue(tester, disabled: false, label: 'Continue');
      expect(lookedUp, [_plainAddress]);
    });

    testWidgets('the wallet\'s own derived address is refused before 1Click is asked', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _derivedAddress);

      expectContinue(tester, disabled: true, label: "Can't Self Transfer");
      expect(lookedUp, isEmpty);
      await tester.pump(_toastLifetime);
    });

    testWidgets('an unanswered lookup lets the send go on', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _unreachableAddress);

      expectContinue(tester, disabled: false, label: 'Continue');
      expect(find.text('NEAR Intents address detected'), findsNothing);
      await tester.pump(_toastLifetime);
    });

    testWidgets('the remote flag off skips the lookup', (tester) async {
      await pumpRecipient(
        tester,
        strategy,
        remoteConfig: FakeRemoteConfigService(_configCheckOff, remote: _configCheckOff),
      );
      await enterRecipient(tester, _depositAddress);

      expectContinue(tester, disabled: false, label: 'Continue');
      expect(find.text('NEAR Intents address detected'), findsNothing);
      expect(lookedUp, isEmpty);
    });

    testWidgets('waits for the remote config before asking 1Click', (tester) async {
      final answer = Completer<RemoteConfigModel?>();
      await pumpRecipient(
        tester,
        strategy,
        remoteConfig: FakeRemoteConfigService(_configWithoutKey)..hold = answer.future,
      );
      await enterRecipient(tester, _plainAddress);

      expect(lookedUp, isEmpty);
      expectContinue(tester, disabled: true, label: 'Verifying Address…');

      answer.complete(_configWithKey);
      await tester.pump();
      await tester.pump();

      expect(lookedUp, [_plainAddress]);
      expectContinue(tester, disabled: false, label: 'Continue');
    });

    testWidgets('a cached partner key serves the lookup while quersi is down', (tester) async {
      final remoteConfig = FakeRemoteConfigService(_configWithKey);
      await pumpRecipient(tester, strategy, remoteConfig: remoteConfig);
      await enterRecipient(tester, _depositAddress);

      expect(remoteConfig.reads, 1);
      expect(lookedUp, [_depositAddress]);
      expect(find.text('NEAR Intents address detected'), findsOneWidget);
      expectContinue(tester, disabled: true, label: "Can't Send to NEAR Intents");
    });

    testWidgets('without a partner key asks quersi once more, then lets the send go on', (tester) async {
      final remoteConfig = FakeRemoteConfigService(_configWithoutKey);
      await pumpRecipient(tester, strategy, remoteConfig: remoteConfig, withOneClick: false);
      await enterRecipient(tester, _plainAddress);

      expect(remoteConfig.reads, 2);
      expect(lookedUp, isEmpty);
      expectContinue(tester, disabled: false, label: 'Continue');
      await tester.pump(_toastLifetime);
    });

    testWidgets('a selection change re-checks the address only after a failed lookup', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _plainAddress);
      final controller = tester.widget<AddressInputField>(find.byType(AddressInputField)).controller;

      controller.value = const TextEditingValue(text: _plainAddress, selection: TextSelection.collapsed(offset: 0));
      await tester.pump();
      await tester.pump();
      expect(lookedUp, [_plainAddress]);

      await enterRecipient(tester, _unreachableAddress);
      controller.value = const TextEditingValue(
        text: _unreachableAddress,
        selection: TextSelection.collapsed(offset: 0),
      );
      await tester.pump();
      await tester.pump();
      expect(lookedUp, [_plainAddress, _unreachableAddress, _unreachableAddress]);
      await tester.pump(_toastLifetime);
    });
  });

  testWidgets('a regular send never consults 1Click', (tester) async {
    await pumpRecipient(tester, const RegularSendStrategy(account: _account));
    await enterRecipient(tester, _depositAddress);

    expectContinue(tester, disabled: false, label: 'Continue');
    expect(find.text('NEAR Intents address detected'), findsNothing);
    expect(lookedUp, isEmpty);
  });
}
