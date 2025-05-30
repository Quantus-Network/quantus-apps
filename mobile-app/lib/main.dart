import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await RustLib.init();
  runApp(const ResonanceWalletApp());
}
