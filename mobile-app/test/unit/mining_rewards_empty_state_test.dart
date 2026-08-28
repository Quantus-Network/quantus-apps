import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/mining_rewards_provider.dart';
import 'package:resonance_network_wallet/services/mining_rewards_service.dart';
import 'package:resonance_network_wallet/v2/screens/settings/mining_rewards_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();

  final noRewards = MiningRewardsData(
    resonanceBlocks: 0,
    schrodingerBlocks: 0,
    diracBlocks: 0,
    planckBlocks: 0,
    planckRewards: BigInt.zero,
    redeemedRewards: BigInt.zero,
    redeemableRewards: BigInt.zero,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'selected_app_locale': 'en'});
    await SettingsService().initialize();
  });

  Color colorOf(WidgetTester tester, String text) => tester.widget<Text>(find.text(text)).style!.color!;

  testWidgets('the zero-blocks card keeps its placeholders on the muted tier', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [miningRewardsProvider.overrideWith((ref) async => noRewards)],
        child: MediaQuery(
          data: const MediaQueryData(size: Size(375, 667)),
          child: Builder(
            builder: (context) => MaterialApp(theme: AppTheme.darkTheme(context), home: const MiningRewardsScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(colorOf(tester, '0'), colors.textMuted);
    expect(colorOf(tester, '0.00'), colors.textMuted);
  });
}
