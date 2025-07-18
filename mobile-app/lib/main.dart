import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await QuantusSdk.init();

  final settingsService = SettingsService();
  final chainHistoryService = ChainHistoryService();
  final substrateService = SubstrateService();

  runApp(
    ChangeNotifierProvider(
      create: (context) => WalletStateManager(
        chainHistoryService,
        settingsService,
        substrateService,
      ),
      child: const ResonanceWalletApp(),
    ),
  );
}
