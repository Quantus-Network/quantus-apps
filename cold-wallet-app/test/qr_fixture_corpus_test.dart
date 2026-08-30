import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// `CallDecoder` names pallets as the metadata does (`ReversibleTransfers`); the manifest
/// uses the chain's own call path (`reversible_transfers.schedule_transfer`).
String callPath(DecodedCall call) {
  final pallet = call.pallet.replaceAllMapped(RegExp(r'(?<=[a-z0-9])[A-Z]'), (m) => '_${m[0]}').toLowerCase();
  return '$pallet.${call.call}';
}

/// Every fixture in `test/fixtures/qr/reduced` is a real signing request. The cold wallet
/// must decode all of them, and show the call the manifest says it should.
///
/// Regenerate the corpus with the quantus-cli `generate_qr_fixtures` example. See the
/// README next to the fixtures.
void main() {
  final root = Directory('test/fixtures/qr/reduced');
  final manifest = jsonDecode(File('${root.path}/manifest.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (manifest['cases'] as List).cast<Map<String, dynamic>>();

  group('QR fixture corpus', () {
    test('manifest and fixture directories agree', () {
      final onDisk =
          root.listSync().whereType<Directory>().map((d) => d.path.split(Platform.pathSeparator).last).toList()..sort();
      final listed = cases.map((c) => c['slug'] as String).toList()..sort();
      expect(onDisk, listed, reason: 'a fixture folder is missing from manifest.json, or vice versa');
    });

    test('every case targets the runtime the app bundles', () {
      expect(manifest['specVersion'], AppConstants.bundledSpecVersion);
      expect(manifest['transactionVersion'], AppConstants.bundledTransactionVersion);
    });

    for (final testCase in cases) {
      final slug = testCase['slug'] as String;
      final dir = '${root.path}/$slug';

      test('$slug decodes to ${testCase['call']}', () {
        final hexText = File('$dir/payload.hex').readAsStringSync().trim();
        final payload = Uint8List.fromList(hex.decode(hexText.substring(2)));
        expect(payload, hasLength(testCase['payloadBytes']));

        final parsed = QuantusPayloadParser.parsePayload(payload);

        expect(parsed.network, manifest['network']);
        // A stale bundled runtime would make the wallet warn on a valid payload.
        expect(parsed.specMatchesBundled, isTrue);

        final call = parsed.call;
        expect(callPath(call), testCase['call']);

        final innerCall = testCase['innerCall'] as String?;
        if (innerCall == null) {
          expect(call.fields.whereType<NestedCallField>(), isEmpty);
        } else {
          final nested = call.fields.whereType<NestedCallField>().single;
          expect(callPath(nested.call), innerCall);
        }
      });

      test('$slug carries the signing request the device scans', () {
        final request = jsonDecode(File('$dir/request.json').readAsStringSync()) as Map<String, dynamic>;
        expect(request['v'], 1);
        expect(request['signer'], testCase['signer']);
        expect(request['payload'], File('$dir/payload.hex').readAsStringSync().trim());

        // One QR frame per UR part, so a viewer never runs past the end of the animation.
        final urParts = File('$dir/ur.txt').readAsLinesSync().where((l) => l.isNotEmpty);
        expect(urParts, hasLength(testCase['frames']));
        final frames = Directory('$dir/frames').listSync().where((f) => f.path.endsWith('.svg'));
        expect(frames, hasLength(testCase['frames']));
      });
    }
  });
}
