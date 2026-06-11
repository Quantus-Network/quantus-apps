import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuantusSdk.init();
  runApp(const ProviderScope(child: ColdWalletApp()));
}
