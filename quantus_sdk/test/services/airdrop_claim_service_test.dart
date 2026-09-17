import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _mnemonic = 'testnet seed';
const _beneficiary = 'qzbeneficiary';

AirdropMatch _dilithium(String address, {bool claimable = true}) => AirdropMatch(
  address: address,
  kind: 'dilithium',
  scheme: 'dilithium-v10-padded',
  claimable: claimable,
  source: 'hd',
  dilithiumKeygen: 'v1:hd:$address',
);

AirdropMatch _wormhole(String address) => AirdropMatch(
  address: address,
  kind: 'wormhole',
  scheme: 'wormhole-rate8-compact',
  claimable: true,
  source: 'hd',
  wormholeSecret: Uint8List(32),
);

/// [alreadyClaimed] maps an address the server holds to the payout address it
/// recorded, or null when it has since been paid out (dropped from /unpaid).
AirdropClaimService _service({
  List<Map<String, dynamic>>? posted,
  int status = 200,
  String body = '{}',
  Map<String, String?> alreadyClaimed = const {},
  List<String>? requests,
}) => AirdropClaimService(
  endpoint: 'https://claims.test',
  client: MockClient((request) async {
    requests?.add('${request.method} ${request.url.path}');
    if (request.url.path == '/unpaid') {
      final rows = [
        for (final e in alreadyClaimed.entries)
          if (e.value != null) {'address': e.key, 'claim_account': e.value, 'status': 'recorded'},
      ];
      return http.Response(jsonEncode({'rows': rows}), 200);
    }
    expect(request.url.toString(), 'https://claims.test/claim');
    expect(request.headers['Content-Type'], startsWith('application/json'));
    final sent = jsonDecode(request.body) as Map<String, dynamic>;
    posted?.add(sent);
    if (alreadyClaimed.containsKey(sent['address'])) {
      return http.Response('{"error":"address already claimed"}', 409);
    }
    return http.Response(body, status);
  }),
  buildDilithiumClaim: ({required mnemonic, required dilithiumKeygen, required address, required claimAccount}) async {
    expect(mnemonic, _mnemonic);
    return DilithiumClaimBody(
      scheme: 'dilithium-v10-padded',
      address: address,
      claimAccount: claimAccount,
      publicKeyHex: 'pk',
      signatureHex: 'sig:$dilithiumKeygen',
      expiryUnix: 123,
    );
  },
  proveWormhole: ({required wormholeSecret, required claimAccount}) async =>
      WormholeClaimBody(proofKind: 'wormhole_rate8', proofHex: 'proof:$claimAccount'),
);

void main() {
  test('posts one claim per claimable address in the server body shape', () async {
    final posted = <Map<String, dynamic>>[];
    await _service(posted: posted).submitClaims(
      matches: [_dilithium('qza'), _dilithium('qza'), _wormhole('qzw'), _dilithium('qzold', claimable: false)],
      mnemonic: _mnemonic,
      claimAccount: _beneficiary,
    );

    expect(posted, [
      {
        'kind': 'dilithium',
        'scheme': 'dilithium-v10-padded',
        'address': 'qza',
        'claim_account': _beneficiary,
        'public_key': 'pk',
        'signature': 'sig:v1:hd:qza',
        'expiry_unix': 123,
      },
      {'kind': 'wormhole', 'proof_kind': 'wormhole_rate8', 'proof': 'proof:$_beneficiary'},
    ]);
  });

  test('an address the server already holds for this payout address counts as done', () async {
    final posted = <Map<String, dynamic>>[];
    final requests = <String>[];
    await _service(
      posted: posted,
      requests: requests,
      alreadyClaimed: {'qza': _beneficiary},
    ).submitClaims(matches: [_dilithium('qza'), _wormhole('qzw')], mnemonic: _mnemonic, claimAccount: _beneficiary);
    expect(posted.map((p) => p['address'] ?? p['proof']), ['qza', 'proof:$_beneficiary']);
    expect(requests, ['POST /claim', 'GET /unpaid', 'POST /claim']);
  });

  test('an address already paid out is not in the unpaid list and counts as done', () async {
    await _service(
      alreadyClaimed: {'qza': null},
    ).submitClaims(matches: [_dilithium('qza')], mnemonic: _mnemonic, claimAccount: _beneficiary);
  });

  test('an address held for another payout address stops the batch as taken', () async {
    final posted = <Map<String, dynamic>>[];
    await expectLater(
      _service(posted: posted, alreadyClaimed: {'qzb': 'qzsomeoneelse'}).submitClaims(
        matches: [_dilithium('qza'), _dilithium('qzb'), _dilithium('qzc')],
        mnemonic: _mnemonic,
        claimAccount: _beneficiary,
      ),
      throwsA(
        isA<AirdropClaimFailure>()
            .having((f) => f.recorded, 'recorded', 1)
            .having((f) => f.total, 'total', 3)
            .having(
              (f) => f.cause,
              'cause',
              isA<AirdropClaimTaken>().having((t) => t.recordedTo, 'recordedTo', 'qzsomeoneelse'),
            ),
      ),
    );
    expect(posted.map((p) => p['address']), ['qza', 'qzb']);
  });

  test("a rejection surfaces the server's error message and how far the batch got", () {
    expect(
      _service(
        status: 404,
        body: '{"error":"address is not in the snapshot"}',
      ).submitClaims(matches: [_dilithium('qza')], mnemonic: _mnemonic, claimAccount: _beneficiary),
      throwsA(
        isA<AirdropClaimFailure>()
            .having((f) => f.recorded, 'recorded', 0)
            .having(
              (f) => '${f.cause}',
              'cause',
              'Exception: Claim for qza rejected (404): address is not in the snapshot',
            ),
      ),
    );
  });

  test('a rejection without a JSON body is reported verbatim', () {
    expect(
      _service(
        status: 502,
        body: 'Bad Gateway',
      ).submitClaims(matches: [_dilithium('qza')], mnemonic: _mnemonic, claimAccount: _beneficiary),
      throwsA(isA<AirdropClaimFailure>().having((f) => '${f.cause}', 'cause', endsWith('(502): Bad Gateway'))),
    );
  });

  test('nothing claimable fails before the server is contacted', () async {
    final posted = <Map<String, dynamic>>[];
    await expectLater(
      _service(
        posted: posted,
      ).submitClaims(matches: [_dilithium('qzold', claimable: false)], mnemonic: _mnemonic, claimAccount: _beneficiary),
      throwsA(anything),
    );
    expect(posted, isEmpty);
  });
}
