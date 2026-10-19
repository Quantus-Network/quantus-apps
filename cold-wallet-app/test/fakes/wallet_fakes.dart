import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';

const testMnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

final testAccounts = [ColdAccount(label: 'Main key', index: 0, scheme: DilithiumScheme.mlDsa87)];

/// Stands in for the platform: what the device lock and biometrics report,
/// and the prompt the controller asks for where the store answers silently.
class FakeColdAuth extends ColdAuthService {
  /// Mutable: a device lock can be added or removed while the app runs.
  bool canProtect;

  /// A device lock exists, whether or not the OS can keep a key behind it.
  final bool hasLock;
  final bool biometrics;

  /// Android: the store prompts once per process, so later reads need this
  /// fake's prompt in front of them.
  final bool storePromptsOnce;

  bool promptResult = true;
  int prompts = 0;

  /// When set, prompts wait on it so one in flight can be observed.
  Completer<bool>? pendingPrompt;

  FakeColdAuth({this.canProtect = true, this.hasLock = true, this.biometrics = false, this.storePromptsOnce = false});

  @override
  Future<bool> deviceCanProtect() async => canProtect;

  @override
  Future<bool> isDeviceSecure() async => hasLock;

  @override
  Future<bool> canUseBiometrics() async => biometrics;

  @override
  bool get storeAuthenticatesOncePerProcess => storePromptsOnce;

  @override
  Future<bool> promptUser(String reason) async {
    prompts++;
    return pendingPrompt?.future ?? promptResult;
  }
}

/// Waits for the controller's startup read of secure storage.
Future<void> awaitInit(ProviderContainer container) async {
  while (container.read(walletControllerProvider).status == WalletStatus.initializing) {
    final error = container.read(walletControllerProvider).error;
    if (error != null) fail('wallet init failed: $error');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
