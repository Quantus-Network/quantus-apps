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

    test('new accounts are ML-DSA-87 by index and by a path outside the templates', () {
      expect(ColdAccount.atIndexText('3')!.scheme, DilithiumScheme.mlDsa87);
      final p87 = HdWalletService.pathForIndex(3, DilithiumScheme.mlDsa87);
      expect(ColdAccount.atPath(p87, label: 'x')!.scheme, DilithiumScheme.mlDsa87);
      final foreign = ColdAccount.atPath("m/44'/1'/0'", label: 'x')!;
      expect(foreign.scheme, DilithiumScheme.mlDsa87);
      expect(foreign.templateIndex, isNull);
    });

    test('an ML-DSA-65 template path adds back the same ML-DSA-65 key', () {
      final existing = ColdAccount(label: 'Account 4', index: 3, scheme: DilithiumScheme.mlDsa65);
      final readded = ColdAccount.atPath(existing.derivationPath, label: 'x')!;
      expect(readded.scheme, DilithiumScheme.mlDsa65);
      expect(readded.derivationPath, existing.derivationPath);
      expect(readded.derivesSameKey(existing), isTrue);
      expect(readded.templateIndex, 3);
    });

    test('at one index, current scheme sorts before legacy', () {
      final accounts = [
        ColdAccount(label: 'legacy', index: 0, scheme: DilithiumScheme.mlDsa87),
        ColdAccount(label: 'current', index: 0, scheme: DilithiumScheme.mlDsa65),
      ]..sort(ColdAccount.compareByDerivation);
      expect(accounts.map((a) => a.label), ['current', 'legacy']);
    });
  });
}
