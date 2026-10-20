import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/app.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await QuantusSdk.init();
  final options = WindowOptions(
    size: const Size(1200, 800),
    minimumSize: const Size(960, 640),
    title: 'Quantus Wallet',
    backgroundColor: const AppColorsV3.dark().bgVoid,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(const ProviderScope(child: DesktopWalletApp()));
}
