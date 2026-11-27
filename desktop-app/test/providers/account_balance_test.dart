import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/providers/account_balance.dart';

void main() {
  group('totalOf', () {
    test('adds up the balances that have loaded', () {
      final total = totalOf([AsyncValue.data(BigInt.from(2)), AsyncValue.data(BigInt.from(5))]);

      expect(total.value, BigInt.from(7));
    });

    test('of no balances is zero', () {
      expect(totalOf(const []).value, BigInt.zero);
    });

    test('is loading while any balance loads and none has failed', () {
      final total = totalOf([AsyncValue.data(BigInt.one), const AsyncValue<BigInt>.loading()]);

      expect(total.isLoading, isTrue);
      expect(total.hasError, isFalse);
      expect(total.hasValue, isFalse);
    });

    test('fails when any balance fails, even while another is still loading', () {
      final error = StateError('balance failed');
      final total = totalOf([
        const AsyncValue<BigInt>.loading(),
        AsyncValue.error(error, StackTrace.empty),
        AsyncValue.data(BigInt.one),
      ]);

      expect(total.hasError, isTrue);
      expect(total.error, same(error));
    });
  });
}
