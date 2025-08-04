import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await QuantusSdk.init();

  final settingsService = SettingsService();
  final chainHistoryService = ChainHistoryService();
  final substrateService = SubstrateService();

  runApp(const ProviderScope(child: ResonanceWalletApp()));
}
