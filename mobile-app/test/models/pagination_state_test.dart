import 'package:flutter_test/flutter_test.dart';
import 'package:resonance_network_wallet/models/pagination_state.dart';

void main() {
  group('PaginationState.copyWith error semantics', () {
    final baselineError = Exception('fetch failed');
    final baselineStack = StackTrace.current;

    late PaginationState stateWithError;

    setUp(() {
      stateWithError = PaginationState.initial().copyWith(error: baselineError, stackTrace: baselineStack);
    });

    test('omitted error and stackTrace are preserved', () {
      final next = stateWithError.copyWith(isFetching: true);

      expect(next.error, same(baselineError));
      expect(next.stackTrace, baselineStack);
      expect(next.isFetching, isTrue);
    });

    test('clearError sets both to null', () {
      final next = stateWithError.copyWith(clearError: true);

      expect(next.error, isNull);
      expect(next.stackTrace, isNull);
    });

    test('error and stackTrace can be set', () {
      final newError = Exception('other');
      final newStack = StackTrace.empty;

      final next = stateWithError.copyWith(error: newError, stackTrace: newStack);

      expect(next.error, newError);
      expect(next.stackTrace, newStack);
    });

    test('clearError takes precedence over error and stackTrace', () {
      final next = stateWithError.copyWith(clearError: true, error: Exception('ignored'), stackTrace: StackTrace.empty);

      expect(next.error, isNull);
      expect(next.stackTrace, isNull);
    });
  });
}
