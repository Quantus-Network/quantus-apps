import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

void main() {
  group('ColdAccount scheme', () {
    test('JSON without a scheme reads as ML-DSA-87', () {
      final account = ColdAccount.fromJson({'label': 'Account 1', 'index': 0});
      expect(account.scheme, DilithiumScheme.mlDsa87);
      expect(account.derivationPath, HdWalletService.pathForIndex(0, DilithiumScheme.mlDsa87));
    });

    test('scheme round-trips through JSON', () {
      final account = ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumScheme.mlDsa65);
      final restored = ColdAccount.fromJson(account.toJson());
      expect(restored.scheme, DilithiumScheme.mlDsa65);
      expect(restored.derivationPath, account.derivationPath);
    });

    test('the same index derives different paths per scheme', () {
      final a65 = ColdAccount(label: 'a', index: 0, scheme: DilithiumScheme.mlDsa65);
      final a87 = ColdAccount(label: 'a', index: 0, scheme: DilithiumScheme.mlDsa87);
      expect(a65.derivationPath, endsWith("/1'"));
      expect(a87.derivationPath, endsWith("/0'"));
      expect(a65.derivationPath, isNot(a87.derivationPath));
    });

    test('atPath uses the chosen scheme whatever the path ends in', () {
      final p65 = HdWalletService.pathForIndex(3, DilithiumScheme.mlDsa65);
      expect(ColdAccount.atPath(p65, label: 'x', scheme: DilithiumScheme.mlDsa87)!.scheme, DilithiumScheme.mlDsa87);
      final custom = ColdAccount.atPath("m/44'/1'/0'", label: 'x', scheme: DilithiumScheme.mlDsa65)!;
      expect(custom.scheme, DilithiumScheme.mlDsa65);
      expect(custom.derivationPath, "m/44'/1'/0'");
      expect(custom.templateIndex, isNull);
    });

    test('schemeOfPath reads the scheme a last element names', () {
      expect(ColdAccount.schemeOfPath("m/44'/1'/1'"), DilithiumScheme.mlDsa65);
      expect(ColdAccount.schemeOfPath("m/44'/1'/0'"), DilithiumScheme.mlDsa87);
      expect(ColdAccount.schemeOfPath("m/44'/1'/2'"), isNull);
    });
  });
}
