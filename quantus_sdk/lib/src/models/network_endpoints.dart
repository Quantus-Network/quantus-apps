import 'package:collection/collection.dart';
import 'package:quantus_sdk/src/constants/app_constants.dart';

/// URLs that bind the wallet to one network. Defaults come from
/// [AppConstants]; remote config overrides them to move wallets elsewhere.
class NetworkEndpoints {
  final List<String> rpc;
  final List<String> graphQl;
  final String explorer;
  final String senoti;

  const NetworkEndpoints({required this.rpc, required this.graphQl, required this.explorer, required this.senoti});

  static const NetworkEndpoints defaults = NetworkEndpoints(
    rpc: AppConstants.rpcEndpoints,
    graphQl: AppConstants.graphQlEndpoints,
    explorer: AppConstants.explorerEndpoint,
    senoti: AppConstants.senotiEndpoint,
  );

  static const _rpcSchemes = {'http', 'https', 'ws', 'wss'};
  static const _httpSchemes = {'http', 'https'};
  static const _equality = DeepCollectionEquality();

  /// Absent keys keep their defaults. A present key must hold a well-formed
  /// URL (or a non-empty list of them); anything else rejects the whole config.
  factory NetworkEndpoints.fromJson(Map<String, dynamic> json) => NetworkEndpoints(
    rpc: _urls(json, 'rpc', defaults.rpc, _rpcSchemes),
    graphQl: _urls(json, 'graphQl', defaults.graphQl, _httpSchemes),
    explorer: _url(json, 'explorer', defaults.explorer, _httpSchemes),
    senoti: _url(json, 'senoti', defaults.senoti, _httpSchemes),
  );

  Map<String, dynamic> toJson() => {'rpc': rpc, 'graphQl': graphQl, 'explorer': explorer, 'senoti': senoti};

  static String _url(Map<String, dynamic> json, String key, String fallback, Set<String> schemes) {
    final value = json[key];
    return value == null ? fallback : _validUrl(key, value, schemes);
  }

  static List<String> _urls(Map<String, dynamic> json, String key, List<String> fallback, Set<String> schemes) {
    final value = json[key];
    if (value == null) return fallback;
    if (value is! List || value.isEmpty) {
      throw FormatException('Remote config endpoints.$key must be a non-empty list of URLs: $value');
    }
    return List.unmodifiable(value.map((v) => _validUrl(key, v, schemes)));
  }

  static String _validUrl(String key, Object? value, Set<String> schemes) {
    final uri = value is String ? Uri.tryParse(value) : null;
    if (uri == null || !schemes.contains(uri.scheme) || uri.host.isEmpty) {
      throw FormatException('Remote config endpoints.$key is not a ${schemes.join('/')} URL: $value');
    }
    return value.toString().replaceAll(RegExp(r'/+$'), '');
  }

  @override
  bool operator ==(Object other) => other is NetworkEndpoints && _equality.equals(toJson(), other.toJson());

  @override
  int get hashCode => _equality.hash(toJson());
}
