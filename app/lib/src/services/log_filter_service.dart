library log_filter_service;

class LogFilterService {
  final int initialLinesToPrint;
  int _linesProcessed = 0;
  final List<String> keywordsToWatch;
  final List<String> criticalKeywordsDuringSync;

  LogFilterService({
    this.initialLinesToPrint = 20,
    this.keywordsToWatch = const [
      '[peers]',
      'imported',
      'finalized',
      'sealed',
      'proposed',
      // 'best',
      'Miner rewarded:',
      // Critical keywords like error/panic will be in criticalKeywordsDuringSync
    ],
    this.criticalKeywordsDuringSync = const [
      'error',
      'panic',
      'fatal',
      'critical',
      'Error encountered',
      'IO error', // Example of another critical I/O related error
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
      // During sync (and after initial burst, and not critical), be very quiet.
      // We've already checked critical keywords, so effectively we print nothing else here.
      return false;
    } else {
      // When synced (and after initial burst, and not critical), print if it matches normal keywords.
      return keywordsToWatch.any((keyword) => lowerLine.contains(keyword.toLowerCase()));
    }
  }
}
