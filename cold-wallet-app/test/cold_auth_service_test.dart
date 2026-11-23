import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:quantus_cold_wallet/services/cold_auth_service.dart';

void main() {
  test('the Keystore prompt needs API 28', () {
    expect(ColdAuthService.androidCanProtect(27, [BiometricType.strong]), isFalse);
  });

  test('below API 30 only a strong biometric counts; a weak one cannot release a key', () {
    expect(ColdAuthService.androidCanProtect(28, []), isFalse);
    expect(ColdAuthService.androidCanProtect(29, [BiometricType.weak]), isFalse);
    expect(ColdAuthService.androidCanProtect(29, [BiometricType.strong]), isTrue);
    expect(ColdAuthService.androidCanProtect(29, [BiometricType.weak, BiometricType.strong]), isTrue);
  });

  test('from API 30 the device credential stands in', () {
    expect(ColdAuthService.androidCanProtect(30, []), isTrue);
    expect(ColdAuthService.androidCanProtect(34, [BiometricType.weak]), isTrue);
  });
}
