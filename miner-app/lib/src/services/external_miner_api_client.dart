import 'dart:async';

import 'package:http/http.dart' as http;

class ExternalMinerMetrics {
  final double hashRate;
  final int activeJobs;
  final int totalHashes;
  final int workers;
  final int cpuCapacity;
  final int gpuDevices;
  final bool isHealthy;

  ExternalMinerMetrics({
    required this.hashRate,
    required this.activeJobs,
    required this.totalHashes,
    required this.workers,
    required this.cpuCapacity,
    this.gpuDevices = 0,
    required this.isHealthy,
  });

  @override
  String toString() {
    return 'ExternalMinerMetrics(hashRate: ${hashRate.toStringAsFixed(2)} H/s, activeJobs: $activeJobs, totalHashes: $totalHashes, workers: $workers, cpuCapacity: $cpuCapacity, gpuDevices: $gpuDevices, isHealthy: $isHealthy)';
  }
}

class ExternalMinerApiClient {
  final String baseUrl;
  final String metricsUrl;
  final Duration timeout;
  final http.Client _httpClient;

  Timer? _pollTimer;

  // Callbacks for stats updates
  void Function(ExternalMinerMetrics metrics)? onMetricsUpdate;
  void Function(String error)? onError;

  ExternalMinerApiClient({
    this.baseUrl = 'http://127.0.0.1:9833',
    String? metricsUrl,
    this.timeout = const Duration(seconds: 5),
  }) : metricsUrl = metricsUrl ?? 'http://127.0.0.1:9900/metrics',
       _httpClient = http.Client();

  /// Start polling for metrics every second
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollMetrics());
  }

  /// Stop polling for metrics
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Check if currently polling for metrics
  bool get isPolling => _pollTimer?.isActive == true;

  /// Get metrics from external miner Prometheus endpoint
  Future<ExternalMinerMetrics?> getMetrics() async {
    try {
      final response = await _httpClient.get(Uri.parse(metricsUrl)).timeout(timeout);

      if (response.statusCode == 200) {
        return _parsePrometheusMetrics(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Parse Prometheus metrics format
  ExternalMinerMetrics _parsePrometheusMetrics(String metricsText) {
    final lines = metricsText.split('\n');

    double hashRate = 0.0;
    int activeJobs = 0;
    int totalHashes = 0;
    int workers = 0;
    int cpuCapacity = 0;
    int gpuDevices = 0;

    for (final line in lines) {
      if (line.startsWith('#')) continue; // Skip comments

      try {
        if (line.startsWith('miner_hash_rate ')) {
          // Global hash rate metric
          final parts = line.split(' ');
          if (parts.length >= 2) {
            hashRate = double.tryParse(parts.last) ?? 0.0;
          }
        } else if (line.startsWith('miner_active_jobs ')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            activeJobs = int.tryParse(parts.last) ?? 0;
          }
        } else if (line.startsWith('miner_hashes_total ')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            totalHashes = int.tryParse(parts.last) ?? 0;
          }
        } else if (line.startsWith('miner_workers ')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            workers = int.tryParse(parts.last) ?? 0;
          }
        } else if (line.startsWith('miner_effective_cpus ')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            cpuCapacity = int.tryParse(parts.last) ?? 0;
          }
        } else if (line.startsWith('miner_gpu_devices ')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            gpuDevices = int.tryParse(parts.last) ?? 0;
          }
        }
      } catch (e) {
        // Skip invalid lines
        continue;
      }
    }

    final metrics = ExternalMinerMetrics(
      hashRate: hashRate,
      activeJobs: activeJobs,
      totalHashes: totalHashes,
      workers: workers,
      cpuCapacity: cpuCapacity,
      gpuDevices: gpuDevices,
      isHealthy: hashRate > 0 || activeJobs > 0,
    );

    return metrics;
  }

  /// Internal method to poll metrics and notify listeners
  Future<void> _pollMetrics() async {
    try {
      final metrics = await getMetrics();
      if (metrics != null) {
        onMetricsUpdate?.call(metrics);
      } else {
        // Call onMetricsUpdate with zero metrics to indicate no data
        onMetricsUpdate?.call(
          ExternalMinerMetrics(
            hashRate: 0.0,
            activeJobs: 0,
            totalHashes: 0,
            workers: 0,
            cpuCapacity: 0,
            gpuDevices: 0,
            isHealthy: false,
          ),
        );
      }
    } catch (e) {
      onError?.call('Failed to poll miner metrics: $e');
    }
  }

  /// Test if the external miner is reachable
  Future<bool> isReachable() async {
    try {
      final response = await _httpClient.get(Uri.parse(baseUrl)).timeout(const Duration(seconds: 3));

      // Any response (even 404) means the server is running
      return response.statusCode >= 200 && response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  /// Test if the metrics endpoint is available
  Future<bool> isMetricsAvailable() async {
    try {
      final response = await _httpClient.get(Uri.parse(metricsUrl)).timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void dispose() {
    stopPolling();
    _httpClient.close();
  }
}
