import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

// The checkphrase lookup reads its word list from the bundle of the app that
// runs it. An app that does not ship the list shows "Checkphrase unavailable"
// for every address, and the other tests cannot see it: they replace the
// lookup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the app ships the checkphrase word list', () async {
    final list = await rootBundle.loadString('assets/text/human_checkphrase_final_wordlist.txt');

    expect(list.split('\n').where((word) => word.isNotEmpty), hasLength(2048));
  });

  test('an address gets its checkphrase from the real lookup', () async {
    final phrase = await HumanReadableChecksumService().getHumanReadableName(
      'qzpyxSr48YN9EQe2ito734iCReTXjnungmNCSY4Yph1YznEda',
    );

    expect(phrase, isNotNull);
    expect(phrase!.split('-'), everyElement(matches(RegExp(r'^[A-Z][a-z]+$'))));
    expect(phrase, isNot(CheckphraseText.unavailableText));
  });
}
