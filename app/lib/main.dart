import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QuantusSdk.init(); // stub for future FFI setup
  runApp(const MinerApp());
}

class MinerApp extends StatelessWidget {
  const MinerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quantus Miner',
      theme: ThemeData.dark(useMaterial3: true),
      home: const MinerHome(),
    );
  }
}

class MinerHome extends StatelessWidget {
  const MinerHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quantus Miner')),
      body: const Center(child: Text('🚧 Miner UI coming soon 🚧')),
    );
  }
}
