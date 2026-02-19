import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:quantus_miner/src/config/miner_config.dart';

// Data class to hold the parsed metrics
class PrometheusMetrics {
  final bool isMajorSyncing;
  final int? bestBlock;
  final int? targetBlock;
  final int? peerCount;

  PrometheusMetrics({required this.isMajorSyncing, this.bestBlock, this.targetBlock, this.peerCount});

  @override
  String toString() {
    return 'PrometheusMetrics(isMajorSyncing: $isMajorSyncing, bestBlock: $bestBlock, targetBlock: $targetBlock, peerCount: $peerCount)';
  }
}

class PrometheusService {
  final String metricsUrl;

  PrometheusService({String? metricsUrl})
    : metricsUrl = metricsUrl ?? MinerConfig.nodePrometheusUrl(MinerConfig.defaultNodePrometheusPort);

  Future<PrometheusMetrics?> fetchMetrics() async {
    try {
      final response = await http.get(Uri.parse(metricsUrl)).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final lines = response.body.split('\n');

        bool isSyncing = false; // Default to false
        int? bestBlock;
        int? targetBlock;
        int? peerCount;

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
          } else if (line.startsWith('substrate_block_height{status="sync_target"')) {
            final parts = line.split(' ');
            if (parts.length == 2) {
              targetBlock = int.tryParse(parts[1]);
            }
          } else if (line.startsWith('substrate_sub_libp2p_peers_count ') ||
              line.startsWith('substrate_sub_libp2p_kademlia_query_duration_count ') ||
              line.contains('substrate_sub_libp2p_connections_opened_total') ||
              line.contains('substrate_peerset_num_discovered_peers')) {
            // Try various peer-related metrics
            final parts = line.split(' ');
            if (parts.length >= 2) {
              final value = int.tryParse(parts.last);
              if (value != null && value > 0) {
                peerCount = value;
              }
            }
          }
        }

        // If substrate_sub_libp2p_is_major_syncing is not present, but target is way ahead of best,
        // consider it syncing. This is a fallback.
        if (bestBlock != null &&
            targetBlock != null &&
            (targetBlock - bestBlock) > 5 &&
            !lines.any((l) => l.startsWith('substrate_sub_libp2p_is_major_syncing'))) {
          // If the specific major sync metric isn't there, but there's a clear block difference,
          // infer syncing state.
          isSyncing = true;
        }

        return PrometheusMetrics(
          isMajorSyncing: isSyncing,
          bestBlock: bestBlock,
          targetBlock: targetBlock,
          peerCount: peerCount,
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
