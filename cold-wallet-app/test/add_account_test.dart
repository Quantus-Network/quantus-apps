import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

/// Where an account sits in the wallet's own numbering: what the account list
/// is ordered by, and what the Add Account screen offers next.
void main() {
  group('the slot an account derives from', () {
    test('an indexed account sits at its index', () {
      expect(ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy).templateIndex, 0);
      expect(ColdAccount(label: 'Account 13', index: 12, scheme: DilithiumSchemeExtension.legacy).templateIndex, 12);
    });

    test('a path following the wallet template counts as the index it names', () {
      final typed = ColdAccount(
        label: 'Typed',
        path: ColdAccount(label: 'x', index: 9, scheme: DilithiumSchemeExtension.legacy).derivationPath,
        scheme: DilithiumSchemeExtension.legacy,
      );

      expect(typed.templateIndex, 9);
    });

    test('a path from another wallet claims no slot', () {
      expect(
        ColdAccount(label: 'Elsewhere', path: "m/44'/1'/0'", scheme: DilithiumSchemeExtension.legacy).templateIndex,
        isNull,
      );
      expect(
        ColdAccount(
          label: 'Deeper',
          path: "m/44'/189189'/7'/1'/2'",
          scheme: DilithiumSchemeExtension.legacy,
        ).templateIndex,
        isNull,
      );
    });
  });

  group('the order accounts are listed in', () {
    test('follows the derivation, not the order they were added', () {
      final accounts = [
        ColdAccount(label: 'Account 5', index: 4, scheme: DilithiumSchemeExtension.legacy),
        ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy),
        ColdAccount(label: 'Account 3', index: 2, scheme: DilithiumSchemeExtension.legacy),
      ]..sort(ColdAccount.compareByDerivation);

      expect(accounts.map((a) => a.label), ['Account 1', 'Account 3', 'Account 5']);
    });

    test('a typed template path takes the slot it names, among the indexed ones', () {
      final accounts = [
        ColdAccount(label: 'Account 5', index: 4, scheme: DilithiumSchemeExtension.legacy),
        ColdAccount(
          label: 'Typed',
          path: ColdAccount(label: 'x', index: 1, scheme: DilithiumSchemeExtension.legacy).derivationPath,
          scheme: DilithiumSchemeExtension.legacy,
        ),
        ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy),
      ]..sort(ColdAccount.compareByDerivation);

      expect(accounts.map((a) => a.label), ['Account 1', 'Typed', 'Account 5']);
    });

    test('a path this wallet does not number sorts last, and stably', () {
      final accounts = [
        ColdAccount(label: 'Zed', path: "m/44'/2'/0'", scheme: DilithiumSchemeExtension.legacy),
        ColdAccount(label: 'Elsewhere', path: "m/44'/1'/0'", scheme: DilithiumSchemeExtension.legacy),
        ColdAccount(label: 'Account 1', index: 0, scheme: DilithiumSchemeExtension.legacy),
      ]..sort(ColdAccount.compareByDerivation);

      expect(accounts.map((a) => a.label), ['Account 1', 'Elsewhere', 'Zed']);
    });
  });
}
