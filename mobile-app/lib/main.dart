import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:resonance_network_wallet/features/main/services/wallet_state_manager.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await QuantusSdk.init();
  runApp(ChangeNotifierProvider(create: (_) => WalletStateManager(), child: const ResonanceWalletApp()));
}
