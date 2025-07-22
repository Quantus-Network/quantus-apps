import 'dart:async';
import 'package:http/http.dart' as http;

// Data class to hold the parsed metrics
class PrometheusMetrics {
  final bool isMajorSyncing;
  final int? bestBlock;
  final int? targetBlock;

  PrometheusMetrics({
    required this.isMajorSyncing,
    this.bestBlock,
    this.targetBlock,
  });

  @override
  String toString() {
    return 'PrometheusMetrics(isMajorSyncing: $isMajorSyncing, bestBlock: $bestBlock, targetBlock: $targetBlock)';
  }
}

class PrometheusService {
  final String metricsUrl;

  PrometheusService({this.metricsUrl = 'http://127.0.0.1:9616/metrics'});

  Future<PrometheusMetrics?> fetchMetrics() async {
    try {
      final response = await http
          .get(Uri.parse(metricsUrl))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');

        bool isSyncing = false; // Default to false
        int? bestBlock;
        int? targetBlock;

        for (var line in lines) {
          if (line.startsWith('substrate_sub_libp2p_is_major_syncing')) {
            final parts = line.split(' ');
            if (parts.length == 2) {
              isSyncing = parts[1] == '1';
            }
          } else if (line.startsWith('substrate_block_height{status="best"')) {
            final parts = line.split(' ');
            if (parts.length == 2) {
              bestBlock = int.tryParse(parts[1]);
            }
          } else if (line.startsWith(
            'substrate_block_height{status="sync_target"',
          )) {
            final parts = line.split(' ');
            if (parts.length == 2) {
              targetBlock = int.tryParse(parts[1]);
            }
          }
        }

        // If substrate_sub_libp2p_is_major_syncing is not present, but target is way ahead of best,
        // consider it syncing. This is a fallback.
        if (bestBlock != null &&
            targetBlock != null &&
            (targetBlock - bestBlock) > 5 &&
            !lines.any(
              (l) => l.startsWith('substrate_sub_libp2p_is_major_syncing'),
            )) {
          // If the specific major sync metric isn't there, but there's a clear block difference,
          // infer syncing state.
          isSyncing = true;
        }

        return PrometheusMetrics(
          isMajorSyncing: isSyncing,
          bestBlock: bestBlock,
          targetBlock: targetBlock,
        );
      } else {
        // Request failed (e.g., 404, 500)
        // Silently return null, let caller handle it.
        return null;
      }
    } catch (e) {
      // Error during HTTP request (e.g., timeout, connection error)
      // Silently return null, let caller handle it.
      return null;
    }
  }
}
