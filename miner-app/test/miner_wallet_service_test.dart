import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';

void main() {
  final wallet = MinerWalletService();

  // A valid 24-word BIP-39 mnemonic. Do NOT use for real wallets.
  const validMnemonic =
      'situate more drip void arrest just action prepare engine undo honey delay '
      'sponsor come achieve symptom crumble solution glass garden fury valid garbage old';

  group('findInvalidMnemonicWords', () {
    test('returns empty list for a fully valid mnemonic', () {
      expect(wallet.findInvalidMnemonicWords(validMnemonic), isEmpty);
    });

    test('returns empty list for a valid mnemonic with extra whitespace', () {
      final messy = '  ${validMnemonic.replaceAll(' ', '   ')}\n';
      expect(wallet.findInvalidMnemonicWords(messy), isEmpty);
    });

    test('flags a single typo with its 1-based position', () {
      final words = validMnemonic.split(' ');
      words[2] = 'driip';
      final result = wallet.findInvalidMnemonicWords(words.join(' '));

      expect(result, hasLength(1));
      expect(result.first.word, 'driip');
      expect(result.first.position, 3);
    });

    test('flags multiple invalid words preserving order and positions', () {
      final words = validMnemonic.split(' ');
      words[0] = 'foobar';
      words[5] = 'qwerty';
      words[23] = 'notaword';
      final result = wallet.findInvalidMnemonicWords(words.join(' '));

      expect(result.map((w) => w.word).toList(), ['foobar', 'qwerty', 'notaword']);
      expect(result.map((w) => w.position).toList(), [1, 6, 24]);
    });

    test('does NOT flag words that are valid but in the wrong order', () {
      final reversed = validMnemonic.split(' ').reversed.join(' ');
      // All words still in the BIP-39 wordlist, so the wordlist check passes.
      // The checksum would fail, but that is validateMnemonic's job.
      expect(wallet.findInvalidMnemonicWords(reversed), isEmpty);
      expect(wallet.validateMnemonic(reversed), isFalse);
    });

    test('accepts uppercase / mixed-case input (normalized to lowercase)', () {
      expect(wallet.findInvalidMnemonicWords(validMnemonic.toUpperCase()), isEmpty);
      expect(wallet.validateMnemonic(validMnemonic.toUpperCase()), isTrue);

      final words = validMnemonic.split(' ');
      words[0] = 'Situate';
      words[1] = 'MORE';
      expect(wallet.findInvalidMnemonicWords(words.join(' ')), isEmpty);
      expect(wallet.validateMnemonic(words.join(' ')), isTrue);
    });

    test('reports invalid words in their normalized (lowercase) form', () {
      final words = validMnemonic.split(' ');
      words[0] = 'FOOBAR';
      final result = wallet.findInvalidMnemonicWords(words.join(' '));
      expect(result, hasLength(1));
      expect(result.first.word, 'foobar');
      expect(result.first.position, 1);
    });

    test('returns empty list for an empty string', () {
      expect(wallet.findInvalidMnemonicWords(''), isEmpty);
      expect(wallet.findInvalidMnemonicWords('   '), isEmpty);
    });

    test('handles a 12-word mnemonic', () {
      const valid12 = 'human snow truck virus now jaguar wall brisk shoe craft gravity diesel';
      expect(wallet.findInvalidMnemonicWords(valid12), isEmpty);

      final words = valid12.split(' ');
      words[4] = 'nowww';
      final result = wallet.findInvalidMnemonicWords(words.join(' '));
      expect(result, hasLength(1));
      expect(result.first.word, 'nowww');
      expect(result.first.position, 5);
    });
  });
}
