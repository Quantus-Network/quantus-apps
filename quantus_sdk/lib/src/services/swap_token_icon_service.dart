import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
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

/// Token logos: CoinGecko's, downloaded once and kept on disk by URL (a new
/// logo gets a new URL), else the one on the token contract on NEAR. A
/// NEP-141 token's `ft_metadata` and a NEP-245 token's
/// `mt_metadata_base_by_token_id` carry an `icon`, a data URI or an https
/// URL. Each logo is fetched once a session; a failed fetch is forgotten so
/// the next ask tries again.
class SwapTokenIconService {
  final NearRpcService _rpc;
  final http.Client _client;
  final Future<Directory> Function() _cacheDirectory;
  final _icons = <String, Future<SwapTokenIcon?>>{};

  SwapTokenIconService({NearRpcService? rpc, http.Client? client, Future<Directory> Function()? cacheDirectory})
    : _rpc = rpc ?? NearRpcService(client: client),
      _client = client ?? http.Client(),
      _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory;

  /// [token]'s logo; null when CoinGecko has none and no listing of its
  /// symbol on NEAR carries one.
  Future<SwapTokenIcon?> iconFor(SwapToken token) {
    final imageUrl = token.imageUrl;
    if (imageUrl != null) return _once(imageUrl, () => _kept(Uri.parse(imageUrl)));
    final assetId = token.iconAssetId;
    if (assetId == null) return Future.value();
    return _once(assetId, () => _nearIcon(assetId));
  }

  Future<SwapTokenIcon?> _once(String key, Future<SwapTokenIcon?> Function() fetch) => _icons[key] ??= () async {
    try {
      return await fetch();
    } catch (_) {
      _icons.remove(key);
      rethrow;
    }
  }();

  /// [uri]'s image from the disk cache, downloaded into it the first time.
  /// The file holds the MIME type, a newline, then the bytes.
  Future<SwapTokenIcon> _kept(Uri uri) async {
    final dir = await _cacheDirectory();
    final file = File('${dir.path}/swap_token_icons/${sha256.convert(utf8.encode('$uri'))}');
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final newline = bytes.indexOf(10);
      return SwapTokenIcon(bytes.sublist(newline + 1), utf8.decode(bytes.sublist(0, newline)));
    }
    final icon = await _download(uri);
    final partial = File('${file.path}.part');
    await partial.create(recursive: true);
    await partial.writeAsBytes([...utf8.encode('${icon.mimeType}\n'), ...icon.bytes]);
    await partial.rename(file.path);
    return icon;
  }

  Future<SwapTokenIcon?> _nearIcon(String assetId) async {
    final icon = await _metadataIcon(assetId);
    if (icon == null) return null;
    final uri = Uri.tryParse(icon);
    if (uri == null || !(uri.isScheme('data') || uri.isScheme('https'))) {
      quantusPrint('$assetId has no usable icon: $icon');
      return null;
    }
    if (uri.isScheme('data')) return SwapTokenIcon(uri.data!.contentAsBytes(), uri.data!.mimeType);
    return _download(uri);
  }

  Future<SwapTokenIcon> _download(Uri uri) async {
    final response = await _client.get(uri);
    if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}', uri);
    final mime = response.headers['content-type']?.split(';').first.trim();
    return SwapTokenIcon(response.bodyBytes, mime ?? 'application/octet-stream');
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
