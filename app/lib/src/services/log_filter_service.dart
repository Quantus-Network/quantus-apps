library log_filter_service;

class LogFilterService {
  final int initialLinesToPrint;
  int _linesProcessed = 0;
  final List<String> keywordsToWatch;

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
      'error',
      'panic',
      // 'fail'
    ],
  });

  bool shouldPrintLine(String line) {
    _linesProcessed++;
    if (_linesProcessed <= initialLinesToPrint) {
      return true;
    }
    final lowerLine = line.toLowerCase();
    for (var keyword in keywordsToWatch) {
      if (lowerLine.contains(keyword.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
