import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/bootstrap/app_bootstrap.dart';
import 'package:resonance_network_wallet/providers/local_auth_provider.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/local_auth_user_approval.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../fakes.dart' show FakeLocalAuthentication;

class _WalletPresent extends Fake implements SettingsService {
  @override
  Future<bool> getHasWallet() async => true;
}

void main() {
  late FakeLocalAuthentication device;
  late LocalAuthService service;
  late LocalAuthUserApproval approval;

  setUp(() {
    device = FakeLocalAuthentication();
    service = LocalAuthService.withDependencies(localAuth: device, settingsService: _WalletPresent());
    approval = LocalAuthUserApproval(service);
  });

  test('a passed prompt is approved', () async {
    expect(await approval.approve(reason: 'Authenticate to confirm transaction'), ApprovalResult.approved);
    expect(device.authenticateCalls, 1);
  });

  test('a failed or dismissed prompt is declined', () async {
    device.authenticateResult = false;

    expect(await approval.approve(reason: 'Authenticate to confirm transaction'), ApprovalResult.declined);
    expect(device.authenticateCalls, 1);
  });

  test('a phone with no screen lock is approved without a prompt, as before', () async {
    device.deviceSupported = false;

    expect(await approval.approve(reason: 'Authenticate to confirm transaction'), ApprovalResult.approved);
    expect(device.authenticateCalls, 0);
  });

  test('approval is available with a screen lock and not set up without one', () async {
    expect(await approval.availability(), ApprovalAvailability.available);

    device.deviceSupported = false;
    expect(await approval.availability(), ApprovalAvailability.notSetUp);
  });

  test('the app binds wallet_core\'s approval to the phone\'s authentication', () async {
    final container = ProviderContainer(
      overrides: [...mobileWalletCoreOverrides(), localAuthServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final bound = container.read(userApprovalProvider);
    expect(bound, isA<LocalAuthUserApproval>());
    expect(await bound.approve(reason: 'Authenticate to confirm transaction'), ApprovalResult.approved);
    expect(device.authenticateCalls, 1);
  });
}
