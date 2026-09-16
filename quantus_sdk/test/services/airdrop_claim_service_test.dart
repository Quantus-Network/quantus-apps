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

AirdropClaimService _service({List<Map<String, dynamic>>? posted, int status = 200, String body = '{}'}) =>
    AirdropClaimService(
      endpoint: 'https://claims.test',
      client: MockClient((request) async {
        expect(request.url.toString(), 'https://claims.test/claim');
        expect(request.headers['Content-Type'], startsWith('application/json'));
        posted?.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(body, status);
      }),
      buildDilithiumClaim:
          ({required mnemonic, required dilithiumKeygen, required address, required claimAccount}) async {
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

  test("a rejection surfaces the server's error message", () {
    expect(
      _service(
        status: 409,
        body: '{"error":"address already claimed"}',
      ).submitClaims(matches: [_dilithium('qza')], mnemonic: _mnemonic, claimAccount: _beneficiary),
      throwsA(predicate((e) => '$e' == 'Exception: Claim for qza rejected (409): address already claimed')),
    );
  });

  test('a rejection without a JSON body is reported verbatim', () {
    expect(
      _service(
        status: 502,
        body: 'Bad Gateway',
      ).submitClaims(matches: [_dilithium('qza')], mnemonic: _mnemonic, claimAccount: _beneficiary),
      throwsA(predicate((e) => '$e'.endsWith('(502): Bad Gateway'))),
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
