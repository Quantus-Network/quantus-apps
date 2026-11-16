import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_core/utils/recovery_phrase.dart';

void main() {
  group('recoveryPhraseWords', () {
    test('splits on runs of spaces and drops the empty words between them', () {
      expect(recoveryPhraseWords('  abandon   ability able  '), ['abandon', 'ability', 'able']);
    });

    test('ignores a line break at either end', () {
      expect(recoveryPhraseWords('\nabandon ability\n'), ['abandon', 'ability']);
    });

    test('finds no words in a phrase of only spaces, or in nothing', () {
      expect(recoveryPhraseWords('    '), isEmpty);
      expect(recoveryPhraseWords(''), isEmpty);
    });
  });
}
