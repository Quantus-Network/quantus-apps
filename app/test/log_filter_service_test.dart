import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_miner/src/services/log_filter_service.dart'; // Adjust import path as necessary

void main() {
  group('LogFilterService', () {
    late LogFilterService logFilterService;

    setUp(() {
      // Default service for most tests
      logFilterService = LogFilterService(
        initialLinesToPrint: 3, // Using a smaller number for easier testing
        keywordsToWatch: ['apple', 'banana', '[error]'],
      );
    });

    test('should print initial lines regardless of content', () {
      expect(logFilterService.shouldPrintLine('Line 1: boring content', 1), isTrue);
      expect(logFilterService.shouldPrintLine('Line 2: also boring', 2), isTrue);
      expect(logFilterService.shouldPrintLine('Line 3: still boring', 3), isTrue);
    });

    test('should not print lines after initial count if no keyword match', () {
      expect(logFilterService.shouldPrintLine('Line 4: boring content again', 4), isFalse);
      expect(logFilterService.shouldPrintLine('Line 5: no keywords here', 5), isFalse);
    });

    test('should print lines after initial count if keyword matches (case insensitive)', () {
      expect(logFilterService.shouldPrintLine('Line 4: got an Apple here', 4), isTrue);
      expect(logFilterService.shouldPrintLine('Line 5: I love BaNaNzA', 5), isFalse); // Corrected: banana, not bananza
      expect(logFilterService.shouldPrintLine('Line 5: I love BANANA', 5), isTrue);
      expect(logFilterService.shouldPrintLine('Line 6: This is an [ERROR] message', 6), isTrue);
    });

    test('should handle empty keywords list (only prints initial lines)', () {
      final serviceWithNoKeywords = LogFilterService(initialLinesToPrint: 2, keywordsToWatch: []);
      expect(serviceWithNoKeywords.shouldPrintLine('Line 1', 1), isTrue);
      expect(serviceWithNoKeywords.shouldPrintLine('Line 2', 2), isTrue);
      expect(serviceWithNoKeywords.shouldPrintLine('Line 3: no keywords configured', 3), isFalse);
    });

    test('should handle zero initial lines (only prints keyword matches)', () {
      final serviceWithZeroInitial = LogFilterService(initialLinesToPrint: 0, keywordsToWatch: ['important']);
      expect(serviceWithZeroInitial.shouldPrintLine('Line 1: not important', 1), isFalse);
      expect(serviceWithZeroInitial.shouldPrintLine('Line 2: very IMPORTANT stuff', 2), isTrue);
    });

    test('should handle keywords with special characters if necessary (though current is simple)', () {
      // This test is more for future-proofing if keywords become regex-like
      // For now, it tests the existing behavior with a keyword that includes a bracket.
      expect(logFilterService.shouldPrintLine('Line 4: this has an [error] somewhere', 4), isTrue);
    });

    test('keywordsToWatch are treated case insensitively by the filter logic', () {
      final service = LogFilterService(initialLinesToPrint: 0, keywordsToWatch: ['KeyWord']);
      expect(service.shouldPrintLine('this is a keyword match', 1), isTrue);
      expect(service.shouldPrintLine('this is a KEYWORD match', 1), isTrue);
      expect(service.shouldPrintLine('this is a kEyWoRd match', 1), isTrue);
    });
  });
}
