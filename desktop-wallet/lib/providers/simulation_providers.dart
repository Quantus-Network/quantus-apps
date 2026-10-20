import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Mnemonic of a signer standing in for the cold wallet during UX testing,
/// from `--dart-define=SIMULATED_SIGNER_MNEMONIC=...`. Debug builds without
/// it fall back to the well-known development account.
const simulatedSignerMnemonic = String.fromEnvironment('SIMULATED_SIGNER_MNEMONIC');

/// Null in release builds that were not given a signer: then nothing on
/// screen can sign without the cold wallet.
final simulatedColdWalletProvider = Provider<SimulatedColdWallet?>((ref) {
  if (simulatedSignerMnemonic.isNotEmpty) return SimulatedColdWallet.fromMnemonic(simulatedSignerMnemonic);
  return kDebugMode ? SimulatedColdWallet.dev() : null;
});
