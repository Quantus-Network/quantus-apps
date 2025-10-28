import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:polkadart/polkadart.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

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

  @override
  Future<bool> healthCheckImpl(Endpoint endpoint) async {
    final queryBody = jsonEncode({'query': 'query { __typename }'});

    final response = await http
        .post(Uri.parse(endpoint.url), headers: {'Content-Type': 'application/json'}, body: queryBody)
        .timeout(const Duration(seconds: 5));

    print('GraphQL healthCheckImpl: ${response.statusCode}');
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      print('GraphQL healthCheckImpl: $jsonResponse');
      if (jsonResponse.containsKey('data')) {
        return true;
      }
    }
    return false;
  }
}

class RpcEndpointService extends RedundantEndpointService {
  static final RpcEndpointService _instance = RpcEndpointService._internal();

  factory RpcEndpointService() => _instance;

  RpcEndpointService._internal() : super(endpoints: AppConstants.rpcEndpoints.map((e) => Endpoint(url: e)).toList());

  String get bestEndpointUrl => endpoints.first.url;

  Future<T> rpcTask<T>(Future<T> Function(Uri uri) task) async {
    return _executeTask((url) => task(Uri.parse(url)));
  }

  @override
  Future<bool> healthCheckImpl(Endpoint endpoint) async {
    final provider = Provider.fromUri(Uri.parse(endpoint.url));
    final result = await provider.send('system_health', []).timeout(const Duration(seconds: 7));
    print('RPC healthCheckImpl: $result');
    return result.error == null;
  }
}

abstract class RedundantEndpointService {
  final List<Endpoint> endpoints;
  Timer? _healthCheckTimer;

  RedundantEndpointService({required this.endpoints}) {
    startHealthCheck();
  }

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
    print('Sorted endpoints: ${endpoints.map((e) => e.url).join(', ')}');
    print('Latency: ${endpoints.map((e) => e.latency).join(', ')}');
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

        endpoint.latency ??= DateTime.now().difference(startTime);
        endpoint.lastSuccess = DateTime.now();

        _sortServers();
        return result;
      } catch (e) {
        lastError = e;
        logEndpointFailure(endpoint, e);
      }
    }

    _sortServers();
    throw lastError ?? Exception('All endpoints failed');
  }

  void logEndpointFailure(Endpoint endpoint, dynamic error) {
    if (!_connectivityIsOffline) {
      if (_isReachabilityError(error)) {
        print('Reachability error on endpoint: ${endpoint.url}: $error');
      }
      endpoint.lastFailure = DateTime.now();
      endpoint.latency = const Duration(days: 365);
    }
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    return _executeTask((url) => http.get(Uri.parse('$url$path'), headers: _mergedHeaders(headers)));
  }

  Future<http.Response> post({String? path, Map<String, String>? headers, String? body}) async {
    return _executeTask(
      (url) => http.post(Uri.parse('$url${(path ?? '')}'), body: body, headers: _mergedHeaders(headers)),
    );
  }

  void startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      healthCheck();
    });
  }

  void stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  Future<void> healthCheck() async {
    print('healthCheck!');
    // note this has different semantics from executeTask - it's more lenient and does not penalize 
    // endpoints that are failing.
    for (final endpoint in endpoints) {
      final startTime = DateTime.now();
      try {
        final success = await healthCheckImpl(endpoint);

        endpoint.latency = DateTime.now().difference(startTime);

        if (success) {
          endpoint.lastSuccess = DateTime.now();
        } else {
          throw Exception('Health check failed');
        }
      } catch (e) {
        print('Health check failed: $e');
      }
    }

    _sortServers();
  }

  void dispose() {
    stopHealthCheck();
  }
  
  Future<bool> healthCheckImpl(Endpoint endpoint);
}
