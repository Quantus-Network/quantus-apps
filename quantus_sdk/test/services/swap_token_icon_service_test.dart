import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

const _svg = '<svg xmlns="http://www.w3.org/2000/svg"/>';
const _png = [0x89, 0x50, 0x4E, 0x47];

SwapToken _token(String assetId, {String? iconAssetId}) => SwapToken(
  assetId: assetId,
  symbol: 'X',
  network: 'ETH',
  decimals: 6,
  usdPrice: 1,
  iconAssetId: iconAssetId ?? assetId,
);

/// A NEAR RPC answering view calls from [metadata] by `account.method`, and an
/// image host answering every GET with a PNG.
class _Near {
  final Map<String, Object?> metadata;
  final calls = <(String, String, Map<String, dynamic>)>[];
  final gets = <Uri>[];

  _Near(this.metadata);

  Future<http.Response> handle(http.Request r) async {
    if (r.method == 'GET') {
      gets.add(r.url);
      return http.Response.bytes(_png, 200, headers: {'content-type': 'image/png; charset=binary'});
    }
    final params = (jsonDecode(r.body) as Map<String, dynamic>)['params'] as Map<String, dynamic>;
    final account = params['account_id'] as String;
    final method = params['method_name'] as String;
    calls.add((account, method, jsonDecode(utf8.decode(base64Decode(params['args_base64'] as String)))));
    if (!metadata.containsKey('$account.$method')) return http.Response('{"error":{"message":"down"}}', 500);
    return http.Response(
      jsonEncode({
        'result': {'result': utf8.encode(jsonEncode(metadata['$account.$method']))},
      }),
      200,
    );
  }
}

SwapTokenIconService _service(_Near near) => SwapTokenIconService(client: MockClient(near.handle));

void main() {
  test('reads a NEP-141 logo out of ft_metadata as the bytes of its data URI', () async {
    final near = _Near({
      'eth.omft.near.ft_metadata': {
        'symbol': 'ETH',
        'icon': 'data:image/svg+xml;base64,${base64Encode(utf8.encode(_svg))}',
      },
    });
    final icon = await _service(near).iconFor(_token('nep141:eth.omft.near'));
    expect(icon!.isSvg, isTrue);
    expect(utf8.decode(icon.bytes), _svg);
    expect(near.calls.single.$3, isEmpty);
  });

  test('reads a NEP-245 logo by token id and downloads its https URL', () async {
    final near = _Near({
      'v2_1.omni.hot.tg.mt_metadata_base_by_token_id': [
        {'symbol': 'BNB', 'icon': 'https://img.test/bnb.png'},
      ],
    });
    final icon = await _service(near).iconFor(_token('nep245:v2_1.omni.hot.tg:56_11111111111111111111'));
    expect(icon!.isSvg, isFalse);
    expect(icon.mimeType, 'image/png');
    expect(icon.bytes, _png);
    expect(near.calls.single.$3, {
      'token_ids': ['56_11111111111111111111'],
    });
    expect(near.gets.single.toString(), 'https://img.test/bnb.png');
  });

  test('takes the logo from another listing of the symbol when the token is not on NEAR', () async {
    final near = _Near({
      'zec.omft.near.ft_metadata': {'icon': 'data:image/png;base64,${base64Encode(_png)}'},
    });
    final icon = await _service(near).iconFor(_token('1cs_v1:sol:spl:A7bd', iconAssetId: 'nep141:zec.omft.near'));
    expect(icon!.mimeType, 'image/png');
    expect(icon.bytes, _png);
  });

  test('has no logo without a NEAR listing, without an icon, or with a junk icon', () async {
    final near = _Near({
      'wrap.near.ft_metadata': {'icon': null},
      'v2_1.omni.hot.tg.mt_metadata_base_by_token_id': [
        {'icon': 'todo'},
      ],
    });
    final service = _service(near);
    const offNear = SwapToken(assetId: '1cs_v1:sol:spl:x', symbol: 'X', network: 'SOL', decimals: 6, usdPrice: 1);
    expect(await service.iconFor(offNear), isNull);
    expect(await service.iconFor(_token('nep141:wrap.near')), isNull);
    expect(await service.iconFor(_token('nep245:v2_1.omni.hot.tg:143_1')), isNull);
    expect(near.calls, hasLength(2));
    expect(near.gets, isEmpty);
  });

  test('fetches each listing once and forgets a failed fetch', () async {
    final near = _Near({});
    final service = _service(near);
    final token = _token('nep141:eth.omft.near');
    await expectLater(service.iconFor(token), throwsA(isA<NearRpcException>()));
    near.metadata['eth.omft.near.ft_metadata'] = {'icon': 'data:image/png;base64,${base64Encode(_png)}'};
    expect((await service.iconFor(token))!.mimeType, 'image/png');
    expect((await service.iconFor(token))!.mimeType, 'image/png');
    expect(near.calls, hasLength(2));
  });
}
