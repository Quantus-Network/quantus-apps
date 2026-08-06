import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:polkadart/polkadart.dart' show Provider;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/src/services/network/keep_alive_http_provider.dart';
import 'package:quantus_sdk/src/utils/print.dart';
import 'package:quantus_sdk/src/utils/timing.dart';

// This set of classes implements redundant endpoints using a strategy to select the best endpoints and to retry failed requests
// on different endpoints.

class Endpoint {
  final String url;
  Duration? latency;
  DateTime? lastSuccess;
  DateTime? lastFailure;

  Endpoint({required this.url, this.latency, this.lastSuccess, this.lastFailure});
}

class GraphQlEndpointService extends RedundantEndpointService {
  static final GraphQlEndpointService _instance = GraphQlEndpointService._internal();

  factory GraphQlEndpointService() => _instance;

  GraphQlEndpointService._internal()
    : super(endpoints: AppConstants.graphQlEndpoints.map((e) => Endpoint(url: e)).toList());
}

class RpcEndpointService extends RedundantEndpointService {
  static final RpcEndpointService _instance = RpcEndpointService._internal();

  factory RpcEndpointService() => _instance;

  RpcEndpointService._internal() : super(endpoints: AppConstants.rpcEndpoints.map((e) => Endpoint(url: e)).toList());

  String get bestEndpointUrl => endpoints.first.url;

  final Map<String, Provider> _providers = {};

  /// One provider per endpoint for the app's lifetime, so every RPC reuses the
  /// same keep-alive connection instead of paying a fresh TLS handshake.
  Provider providerFor(String url) => _providers.putIfAbsent(url, () {
    final uri = Uri.parse(url);
    if (uri.scheme == 'http' || uri.scheme == 'https') return KeepAliveHttpProvider(uri);
    return Provider.fromUri(uri);
  });

  Future<T> rpcTask<T>(Future<T> Function(Uri uri) task) async {
    return _executeTask((url) => task(Uri.parse(url)));
  }

  /// Like [rpcTask], but hands the task the endpoint's shared [Provider].
  Future<T> providerTask<T>(Future<T> Function(Provider provider) task) async {
    return _executeTask((url) => task(providerFor(url)));
  }
}

class RedundantEndpointService {
  final List<Endpoint> endpoints;

  /// Shared client so plain HTTP calls reuse keep-alive connections too.
  final http.Client _httpClient = http.Client();

  RedundantEndpointService({required this.endpoints});

  Map<String, String> _mergedHeaders(Map<String, String>? headers) {
    return {'Content-Type': 'application/json', ...?headers};
  }

  void _sortServers() {
    endpoints.sort((a, b) {
      if (a.latency == null && b.latency == null) return 0;
      if (a.latency == null) return 1;
      if (b.latency == null) return -1;
      return a.latency!.compareTo(b.latency!);
    });
  }

  bool _isReachabilityError(dynamic error) {
    return error is SocketException ||
        error is HttpException ||
        (error.toString().contains('Failed host lookup') || error.toString().contains('Connection refused'));
  }

  bool get _connectivityIsOffline {
    return ConnectivityService().currentStatus == NetworkStatus.offline;
  }

  Future<T> _executeTask<T>(Future<T> Function(String url) task) async {
    dynamic lastError;

    for (final endpoint in endpoints) {
      final startTime = DateTime.now();

      try {
        final result = await task(endpoint.url);

        final elapsed = DateTime.now().difference(startTime);
        printTiming('endpoint task ${endpoint.url}', elapsed.inMilliseconds);
        endpoint.latency ??= elapsed;
        endpoint.lastSuccess = DateTime.now();

        _sortServers();
        return result;
      } catch (e) {
        lastError = e;
        printTiming('endpoint task FAILED ${endpoint.url}', DateTime.now().difference(startTime).inMilliseconds);
        logEndpointFailure(endpoint, e);
      }
    }

    _sortServers();
    throw lastError ?? Exception('All endpoints failed');
  }

  void logEndpointFailure(Endpoint endpoint, dynamic error) {
    if (!_connectivityIsOffline) {
      quantusPrint('endpoint failure: ${endpoint.url}: $error');
      if (_isReachabilityError(error)) {
        quantusPrint('Reachability error on endpoint: ${endpoint.url}: $error');
      }
      endpoint.lastFailure = DateTime.now();
      endpoint.latency = const Duration(days: 365);
    }
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return _executeTask((url) => _httpClient.get(Uri.parse('$url$path'), headers: _mergedHeaders(headers)));
  }

  Future<http.Response> post({String? path, Map<String, String>? headers, String? body}) async {
    return _executeTask(
      (url) => _httpClient.post(Uri.parse('$url${(path ?? '')}'), body: body, headers: _mergedHeaders(headers)),
    );
  }
}
