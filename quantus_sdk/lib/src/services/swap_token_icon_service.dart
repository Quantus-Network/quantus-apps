import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:quantus_sdk/src/models/swap_token.dart';
import 'package:quantus_sdk/src/services/near_rpc_service.dart';
import 'package:quantus_sdk/src/utils/print.dart';

/// A token's logo, SVG or raster, as bytes.
class SwapTokenIcon {
  final Uint8List bytes;
  final String mimeType;

  const SwapTokenIcon(this.bytes, this.mimeType);

  bool get isSvg => mimeType == 'image/svg+xml';
}

/// Token logos from the token contracts on NEAR: a NEP-141 token's
/// `ft_metadata` and a NEP-245 token's `mt_metadata_base_by_token_id` carry an
/// `icon`, a data URI or an https URL. Each listing is fetched once; a failed
/// fetch is forgotten so the next ask tries again.
class SwapTokenIconService {
  final NearRpcService _rpc;
  final http.Client _client;
  final _icons = <String, Future<SwapTokenIcon?>>{};

  SwapTokenIconService({NearRpcService? rpc, http.Client? client})
    : _rpc = rpc ?? NearRpcService(client: client),
      _client = client ?? http.Client();

  /// [token]'s logo; null when no listing of its symbol carries one.
  Future<SwapTokenIcon?> iconFor(SwapToken token) {
    final assetId = token.iconAssetId;
    if (assetId == null) return Future.value();
    return _icons[assetId] ??= _fetch(assetId);
  }

  Future<SwapTokenIcon?> _fetch(String assetId) async {
    try {
      final icon = await _metadataIcon(assetId);
      if (icon == null) return null;
      final uri = Uri.tryParse(icon);
      if (uri == null || !(uri.isScheme('data') || uri.isScheme('https'))) {
        quantusPrint('$assetId has no usable icon: $icon');
        return null;
      }
      if (uri.isScheme('data')) return SwapTokenIcon(uri.data!.contentAsBytes(), uri.data!.mimeType);
      final response = await _client.get(uri);
      if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}', uri);
      final mime = response.headers['content-type']?.split(';').first.trim();
      return SwapTokenIcon(response.bodyBytes, mime ?? 'application/octet-stream');
    } catch (_) {
      _icons.remove(assetId);
      rethrow;
    }
  }

  Future<String?> _metadataIcon(String assetId) async {
    final [standard, contract, ...tokenId] = assetId.split(':');
    final meta = switch (standard) {
      'nep141' => await _rpc.view(contract, 'ft_metadata'),
      'nep245' =>
        (await _rpc.view(contract, 'mt_metadata_base_by_token_id', {
                  'token_ids': [tokenId.join(':')],
                })
                as List<dynamic>)
            .firstOrNull,
      _ => throw ArgumentError('$assetId is not a token on NEAR'),
    };
    return (meta as Map<String, dynamic>?)?['icon'] as String?;
  }
}
