import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:quantus_sdk/quantus_sdk.dart';

// This set of classes implements redundant endpoints using a strategy to select the best endpoints and to retry failed requests
// on different endpoints.

class Endpoint {
  final String url;
  Duration? latency;
  DateTime? lastSuccess;
  DateTime? lastFailure;

  Endpoint({
    required this.url,
    this.latency,
    this.lastSuccess,
    this.lastFailure,
  });
}

class GraphQlEndpointService extends RedundantEndpointService {
  static final GraphQlEndpointService _instance = GraphQlEndpointService._internal();
  
  factory GraphQlEndpointService() => _instance;
  
  GraphQlEndpointService._internal() : super(endpoints: AppConstants.graphQlEndpoints.map((e) => Endpoint(url: e)).toList());
}

class RpcEndpointService extends RedundantEndpointService {
  static final RpcEndpointService _instance = RpcEndpointService._internal();
  
  factory RpcEndpointService() => _instance;
  
  RpcEndpointService._internal() : super(endpoints: AppConstants.rpcEndpoints.map((e) => Endpoint(url: e)).toList());

  String get bestEndpointUrl => endpoints.first.url;

  Future<T> rpcTask<T>(Future<T> Function(Uri uri) task) async {
    dynamic lastError;
    
    for (final endpoint in endpoints) {
      final uri = Uri.parse(endpoint.url);
      final startTime = DateTime.now();
      
      try {
        final result = await task(uri);
        
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
    throw lastError ?? Exception('All RPC endpoints failed');
  }
}

class RedundantEndpointService {
  final List<Endpoint> endpoints;

  RedundantEndpointService({
    required this.endpoints,
  });

  Map<String, String> _mergedHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      ...?headers,
    };
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
           (error.toString().contains('Failed host lookup') ||
            error.toString().contains('Connection refused'));
  }

  bool get _connectivityIsOffline {
    return ConnectivityService().currentStatus == NetworkStatus.offline;
  }

  Future<http.Response> get(String path, {Map<String, String>? headers}) async {
    dynamic lastError;
    
    for (final endpoint in endpoints) {
      final url = '${endpoint.url}$path';
      final startTime = DateTime.now();
      
      try {
        final response = await http.get(Uri.parse(url), headers: _mergedHeaders(headers));
        
        endpoint.latency ??= DateTime.now().difference(startTime);
        endpoint.lastSuccess = DateTime.now();
        
        _sortServers();
        return response;
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

  Future<http.Response> post({String? path, Map<String, String>? headers, String? body}) async {
    dynamic lastError;
    
    for (final endpoint in endpoints) {
      final url = '${endpoint.url}${(path ?? '')}';
      final startTime = DateTime.now();
      
      try {
        final response = await http.post(Uri.parse(url), body: body, headers: _mergedHeaders(headers));
        
        endpoint.latency ??= DateTime.now().difference(startTime);
        endpoint.lastSuccess = DateTime.now();
        
        _sortServers();
        return response;
      } catch (e) {
        lastError = e;
        logEndpointFailure(endpoint, e);
      }
    }
    
    _sortServers();
    throw lastError ?? Exception('All endpoints failed');
  }
}