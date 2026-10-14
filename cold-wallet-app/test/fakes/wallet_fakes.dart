import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';

const testMnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

final testAccounts = [ColdAccount(label: 'Main key', index: 0, scheme: DilithiumScheme.mlDsa87)];

/// Stands in for the platform: what the device lock and biometrics report.
class FakeColdAuth extends ColdAuthService {
  final bool canProtect;
  final bool biometrics;

  FakeColdAuth({this.canProtect = true, this.biometrics = false});

  @override
  Future<bool> deviceCanProtect() async => canProtect;

  @override
  Future<bool> canUseBiometrics() async => biometrics;
}

/// Waits for the controller's startup read of secure storage.
Future<void> awaitInit(ProviderContainer container) async {
  while (container.read(walletControllerProvider).status == WalletStatus.initializing) {
    final error = container.read(walletControllerProvider).error;
    if (error != null) fail('wallet init failed: $error');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
