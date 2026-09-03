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

    test('atPath infers the scheme from a template path', () {
      final p65 = HdWalletService.pathForIndex(3, DilithiumScheme.mlDsa65);
      final p87 = HdWalletService.pathForIndex(3, DilithiumScheme.mlDsa87);
      expect(
        ColdAccount.atPath(p65, label: 'x', defaultScheme: DilithiumScheme.mlDsa87)!.scheme,
        DilithiumScheme.mlDsa65,
      );
      expect(
        ColdAccount.atPath(p87, label: 'x', defaultScheme: DilithiumScheme.mlDsa65)!.scheme,
        DilithiumScheme.mlDsa87,
      );
    });

    test('atPath falls back to the default scheme for a foreign path', () {
      final account = ColdAccount.atPath("m/44'/1'/0'", label: 'x', defaultScheme: DilithiumScheme.mlDsa65);
      expect(account!.scheme, DilithiumScheme.mlDsa65);
      expect(account.templateIndex, isNull);
    });

    test('at one index, current scheme sorts before legacy', () {
      final accounts = [
        ColdAccount(label: 'legacy', index: 0, scheme: DilithiumScheme.mlDsa87),
        ColdAccount(label: 'current', index: 0, scheme: DilithiumScheme.mlDsa65),
      ]..sort(ColdAccount.compareByDerivation);
      expect(accounts.map((a) => a.label), ['current', 'legacy']);
    });

    test('walletScheme grows current once any current account is held', () {
      expect(
        ColdAccount.walletScheme([ColdAccount(label: 'a', index: 0, scheme: DilithiumScheme.mlDsa87)]),
        DilithiumScheme.mlDsa87,
      );
      expect(
        ColdAccount.walletScheme([
          ColdAccount(label: 'a', index: 0, scheme: DilithiumScheme.mlDsa87),
          ColdAccount(label: 'b', index: 0, scheme: DilithiumScheme.mlDsa65),
        ]),
        DilithiumScheme.mlDsa65,
      );
    });
  });
}
