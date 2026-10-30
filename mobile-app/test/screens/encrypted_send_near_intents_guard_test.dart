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
const _unreadableAddress = 'qzUNREADABLE';
const _slowAddress = 'qzSLOW';

/// Lets the warning toast a refusal raises expire before the tree is torn down.
const _toastLifetime = Duration(seconds: 3);

final _config = RemoteConfigModel.fromJson(const {});
final _configCheckOff = RemoteConfigModel.fromJson(const {'enableOneClickNearWarning': false});

/// Owns [_derivedAddress]; the secure-storage read fails for [_unreadableAddress].
/// Every address asked about lands in [checked].
class _FakeEncryptedAccountService extends Fake implements EncryptedAccountService {
  final List<String> checked;

  _FakeEncryptedAccountService(this.checked);

  @override
  Future<bool> ownsAddress(String address) async {
    checked.add(address);
    if (address == _unreadableAddress) throw StateError('mnemonic unavailable');
    return address == _derivedAddress;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CheckphraseText.resolveOverride = (_) async => 'Stand-Envelope-Topic-Term-Help';

  final lookedUp = <String>[];
  final selfChecked = <String>[];

  /// 1Click as the guard sees it: history for [_depositAddress] and, once
  /// [holdLookup] completes, for [_slowAddress]; none for any other address,
  /// and no answer at all for [_unreachableAddress]. Built per test, since the
  /// service remembers every answer. A test that holds a lookup creates
  /// [holdLookup] in its own body, inside the fake-async zone.
  late OneClickService oneClick;
  late Completer<void> holdLookup;

  setUp(() async {
    lookedUp.clear();
    selfChecked.clear();
    oneClick = OneClickService(
      client: MockClient((request) async {
        final address = request.url.queryParameters['depositAddress']!;
        lookedUp.add(address);
        if (address == _unreachableAddress) throw http.ClientException('connection refused');
        if (address == _slowAddress) await holdLookup.future;
        final items = address == _depositAddress || address == _slowAddress
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

  Future<void> pumpRecipient(WidgetTester tester, SendStrategy strategy, {RemoteConfigService? remoteConfig}) async {
    final config = remoteConfig ?? FakeRemoteConfigService(_config, remote: _config);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          substrateServiceProvider.overrideWithValue(FakeSubstrateService()),
          recentAddressesServiceProvider.overrideWithValue(FakeRecentAddressesService()),
          encryptedAccountServiceProvider.overrideWith((ref, walletIndex) => _FakeEncryptedAccountService(selfChecked)),
          remoteConfigProvider.overrideWith((ref) => RemoteConfigNotifier(config)),
          oneClickServiceProvider.overrideWithValue(oneClick),
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

    testWidgets('an unanswered lookup lets the send go on without a word', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _unreachableAddress);

      expectContinue(tester, disabled: false, label: 'Continue');
      expect(find.text('NEAR Intents address detected'), findsNothing);
      expect(find.textContaining("Couldn't verify the address"), findsNothing);
      expect(find.text('Private Send'), findsOneWidget);
      expect(lookedUp, [_unreachableAddress]);
    });

    testWidgets('a failed self-send check keeps continue disabled', (tester) async {
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _unreadableAddress);

      expectContinue(tester, disabled: true, label: "Couldn't Verify Address");
      expect(find.textContaining("Couldn't verify the address"), findsOneWidget);
      expect(find.text('NEAR Intents address detected'), findsNothing);
      expect(lookedUp, isEmpty);
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

    testWidgets('a lookup waiting for the remote config does not hold up continue', (tester) async {
      final answer = Completer<RemoteConfigModel?>();
      await pumpRecipient(tester, strategy, remoteConfig: FakeRemoteConfigService(_config)..hold = answer.future);
      await enterRecipient(tester, _depositAddress);

      expect(lookedUp, isEmpty);
      expectContinue(tester, disabled: false, label: 'Continue');

      answer.complete(_config);
      await tester.pump();
      await tester.pump();

      expect(lookedUp, [_depositAddress]);
      expectContinue(tester, disabled: true, label: "Can't Send to NEAR Intents");
    });

    testWidgets('a slow 1Click answer does not hold up continue and blocks once it lands', (tester) async {
      holdLookup = Completer<void>();
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _slowAddress);

      expect(lookedUp, [_slowAddress]);
      expectContinue(tester, disabled: false, label: 'Continue');
      expect(find.text('Private Send'), findsOneWidget);

      holdLookup.complete();
      await tester.pump();
      await tester.pump();

      expectContinue(tester, disabled: true, label: "Can't Send to NEAR Intents");
      expect(find.text('NEAR Intents address detected'), findsOneWidget);
    });

    testWidgets('an answer landing after an edit is dropped', (tester) async {
      holdLookup = Completer<void>();
      await pumpRecipient(tester, strategy);
      await enterRecipient(tester, _slowAddress);
      await enterRecipient(tester, _plainAddress);
      expectContinue(tester, disabled: false, label: 'Continue');

      holdLookup.complete();
      await tester.pump();
      await tester.pump();

      expectContinue(tester, disabled: false, label: 'Continue');
      expect(find.text('NEAR Intents address detected'), findsNothing);
    });

    testWidgets('a cached config serves the lookup while quersi is down', (tester) async {
      final remoteConfig = FakeRemoteConfigService(_config);
      await pumpRecipient(tester, strategy, remoteConfig: remoteConfig);
      await enterRecipient(tester, _depositAddress);

      expect(remoteConfig.reads, 1);
      expect(lookedUp, [_depositAddress]);
      expect(find.text('NEAR Intents address detected'), findsOneWidget);
      expectContinue(tester, disabled: true, label: "Can't Send to NEAR Intents");
    });

    testWidgets('a selection change re-checks the address only after a failed self-send check', (tester) async {
      await pumpRecipient(tester, strategy);
      final controller = tester.widget<AddressInputField>(find.byType(AddressInputField)).controller;

      Future<void> moveSelection(String address) async {
        controller.value = TextEditingValue(text: address, selection: const TextSelection.collapsed(offset: 0));
        await tester.pump();
        await tester.pump();
      }

      await enterRecipient(tester, _plainAddress);
      await moveSelection(_plainAddress);
      expect(lookedUp, [_plainAddress]);

      await enterRecipient(tester, _unreachableAddress);
      await moveSelection(_unreachableAddress);
      expect(lookedUp, [_plainAddress, _unreachableAddress]);

      await enterRecipient(tester, _unreadableAddress);
      await moveSelection(_unreadableAddress);
      expect(selfChecked, [_plainAddress, _unreachableAddress, _unreadableAddress, _unreadableAddress]);
      expect(lookedUp, [_plainAddress, _unreachableAddress]);
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
