import 'package:quantus_miner/src/config/miner_config.dart';

class LogFilterService {
  final int initialLinesToPrint;
  int _linesProcessed = 0;
  final List<String> keywordsToWatch;
  final List<String> criticalKeywordsDuringSync;

  LogFilterService({
    this.initialLinesToPrint = 50, // Increased initial lines to show more startup info
    this.keywordsToWatch = const [
      // Info level logs that users want to see by default
      'info',
      'INFO',
      'Starting',
      'Started',
      'Listening',
      'Connected',
      'Connection',
      'Sync',
      'sync',
      'Block',
      'block',
      'Peer',
      'peer',
      'Mining',
      'mining',
      'Hash',
      'hash',
      'Reward',
      'reward',
      'Transaction',
      'transaction',
      'imported',
      'finalized',
      'sealed',
      'proposed',
      MinerConfig.blockSubmittedLogMarker,
      // Keep existing keywords
      '[peers]',
    ],
    this.criticalKeywordsDuringSync = const [
      'error',
      'panic',
      'fatal',
      'critical',
      'Error encountered',
      'IO error',
      'Failed',
      'failed',
      'WARN',
      'WARNING',
      'warn',
      'warning',
    ],
  });

  void reset() {
    _linesProcessed = 0;
  }

  bool shouldPrintLine(String line, {required bool isNodeSyncing}) {
    _linesProcessed++;

    if (_linesProcessed <= initialLinesToPrint) {
      return true; // Always print initial lines
    }

    final lowerLine = line.toLowerCase();

    // Always print critical messages, regardless of sync state (after initial burst)
    if (criticalKeywordsDuringSync.any((keyword) => lowerLine.contains(keyword.toLowerCase()))) {
      return true;
    }

    if (isNodeSyncing) {
      // During sync, show info level logs and keywords (not just critical messages)
      return keywordsToWatch.any((keyword) => lowerLine.contains(keyword.toLowerCase()));
    } else {
      // When synced (and after initial burst, and not critical), print if it matches normal keywords.
      return keywordsToWatch.any((keyword) => lowerLine.contains(keyword.toLowerCase()));
    }
  }
}
