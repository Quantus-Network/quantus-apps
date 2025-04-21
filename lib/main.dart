import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/main/screens/app.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';

import 'package:resonance_network_wallet/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await RustLib.init();
  runApp(const ResonanceWalletApp());
}

enum Mode {
  schorr,
  dilithium,
}

const mode = Mode.dilithium;

