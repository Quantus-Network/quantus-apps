import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/generated/bell/pallets/balances.dart' as balances_pallet;
import 'package:quantus_sdk/generated/bell/types/sp_runtime/multiaddress/multi_address.dart' as multi_address;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';

import '../extensions.dart';
import '../fakes.dart';

/// Builds each transaction a cold wallet is shown afresh, and counts them.
class _Substrate extends FakeSubstrateService {
  int built = 0;

  @override
  Future<UnsignedTransactionData> getUnsignedTransactionPayload(Account account, RuntimeCall call) async {
    built++;
    return makeUnsignedTransactionData();
  }
}

/// How long the code for [makeUnsignedTransactionData]'s transaction may stay
/// on screen: its era, less the reserve a trip through the cold wallet needs.
final _maxAge = keystoneSignCacheMaxAge(makeUnsignedTransactionData().payloadToSign);

/// How often the screen checks the code's age.
const _check = Duration(seconds: 5);

void main() {
  late _Substrate substrate;

  setUp(() async {
    // The screen speaks the app's chosen language, kept in the settings.
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
    substrate = _Substrate();
    recordTelemetry();
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('telemetrydecksdk'),
      null,
    ),
  );

  /// Shows a cold wallet's request code for a transaction alive for 64 blocks.
  Future<void> showCode(WidgetTester tester) async {
    final cold = makeAccount(3, accountType: AccountType.keystone);
    await tester.pumpApp(
      KeystoneSignScreen(
        session: KeystoneSigningSession(
          account: cold,
          buildCall: () => const balances_pallet.Txs().transferAllowDeath(
            dest: const multi_address.$MultiAddress().id(List<int>.filled(32, 0)),
            value: BigInt.one,
          ),
          cacheKey: KeystoneSignCacheKey.forExtrinsic(accountId: cold.accountId, identity: 'test'),
          submitSigned: (ref, {required unsignedData, required signatureWithPublicKey}) async => '0xhash',
        ),
      ),
      overrides: [
        substrateServiceProvider.overrideWithValue(substrate),
        keystoneSignRequestFramesProvider.overrideWithValue((account, unsigned) => ['UR:QUANTUS-SIGN-REQUEST/1']),
      ],
    );
    await tester.pump();
  }

  testWidgets('a code past its age is built again at the next check', (tester) async {
    await showCode(tester);
    expect(substrate.built, 1);

    await tester.pump(_maxAge);
    await tester.pump(_check);

    expect(substrate.built, 2);
  });

  testWidgets('a code still within its age is kept', (tester) async {
    await showCode(tester);

    await tester.pump(_maxAge - const Duration(seconds: 1));

    expect(substrate.built, 1);
  });
}
